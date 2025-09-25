# ==============================================================================
# Celiac diagnosis prediction and data analysis (R 4.5)
# Caleb Hurwitz
# Refs: Hmisc, ggplot2, epitools, pROC
# ==============================================================================

# ---- Setup -------------------------------------------------------------------
rm(list=ls())
set.seed(123) # ensures later operations can be reproduced

# Packages
required <- c("Hmisc", "ggplot2", "epitools", "pROC")
to_install <- setdiff(required, rownames(installed.packages()))
if (lenght(to_install)) install.packages(to_install)
lapply(required, library, character.only = TRUE)

# ---- Import and Inspection ---------------------------------------------------
data <- read.csv("~/Desktop/celiac_R/celiac_disease_lab_data.csv")
describe(data)

# ---- Consistency Checks ------------------------------------------------------

issue1 <- subset(data, tolower(Diabetes) == "no"  & Diabetes.Type != "None")
issue2 <- subset(data, tolower(Diabetes) == "yes" & Diabetes.Type == "None")

stopifnot(nrow(issue1) == 0)
stopifnot(nrow(issue2) == 0) # either will fail if there are inconsistencies

# ---- Basic EDA ---------------------------------------------------------------
table(data$Gender)
tbl_g_dx <- table(data$Gengder, data$Disease_Diagnose)
tbl_g_dx
chisq.test(tbl_g_dx) #large N so chi-sq fits
oddsratio(tbl_g_dx)
prop.table(tbl_g_dx, margin = 1)

summary(data[, c("Age", "IgA", "IgG", "IgM")])

# Histograms for continuous variables
num_vars <- c("Age", "IgA", "IgG", "IgM")
for (v in num_vars) {
  print(
    ggplot(data, aes(x = .data[[v]])) +
      geom_histogram(binwidth = if (v == "Age") 30 else 30) +
      labs(title = paste("Histogram:", v), x = v, y = "Count") +
      theme_minimal()
    print(p)
    )
}

# ---- Factors -----------------------------------------------------------------
fac_cols <- c("Gender", "Diarrhoea", "Abdominal", "Short_Stature", 
              "Sticky_Stool", "Weight_loss", "Disease_Diagnose")
for (nm in fac_cols) data[[nm]] <- factor(data[[nm]])

# Making sure we are modeling "yes"
data$Disease_Diagnose <- fatcor(data$Disease_Diagnose, levels = c("no", "yes"))

# Ensure numbers are read as numbers in case they were read as characters
data$Age <- as.numeric(data$Age)
data$Age <- as.numeric(data$IgA)
data$Age <- as.numeric(data$IgG)
data$Age <- as.numeric(data$IgM)

# ---- Training and testing ----------------------------------------------------
idx <- sample.int(nrow(data), size = floor(0.7 * nrow(data)))
train <- data[idx, ]
test <- data[-idx, ]

# ---- Logistic regression (no Marsh) ------------------------------------------
# Dropping Marsh here is important because if it was used in the prediction
# model then the accuracy would certainly be very high but it also would 
# not be very realistic since those with Celiac are classified in Marsh stages
model_pre <- glm(
  Disease_Diagnose ~ Age + Gender + IgA + IgG + IgM +
    Diabetes_Status + Diarrhoea + Abdominal +
    Short_Stature + Sticky_Stool + Weight_loss,
  data = train, 
  family = binomial
)

summary(model_pre)

# ---- Evaluation --------------------------------------------------------------
# A great way to display the accuracy of the model is through a confusion matrix
# however, I also decided to use ROC/AUC to give other metrics of accuracy
probs <- predict(model_pre, newdata = test, type = "response")
preds <- ofe;se(probs > 0.5, "yes", "no")
preds <- factor(preds, levels = c("no", "yes"))

cm <- table(Predicted = preds, Actual = test$Disease_Diagnose)
cm
acc <- sum(diag(cm)) / sum(cm)
acc

# ROC/AUC
roc_obj <- pROC::roc(response = test$Disease_Diagnose, predictor = probs, levels = c("no","yes"))
plot(roc_obj, main = sprintf("ROC (AUC = %.3f)", pROC::auc(roc_obj)))

# Odds ratios with 95% Confidence Intervals
or <- data.frame(
  term = names(coef(model_pre)),
  estimate = coef(model_pre),
  se = sqrt(diag(vcov(model_pre)))
)
or$OR  <- exp(or$estimate)
or$LCL <- exp(or$estimate - 1.96*or$se)
or$UCL <- exp(or$estimate + 1.96*or$se)
or
