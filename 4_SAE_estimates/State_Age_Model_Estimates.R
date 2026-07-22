
# Programmer: N. Ganesh
# Date: 03/05/2026

rm(list=ls()) # Clear work space

library(openxlsx)
library(readxl)
library(dplyr)
library(MASS)
library(leaps)
library(fastDummies)

# Set working directory
foldername = "Q3/HTN/Model Estimates";
path = paste0("P:/A335/Common/SAE/", foldername);
setwd(path);

# Estimates below this threshold will be suppressed
n_supp = 25

# Trim quantile for sample size
trim.q = 0.8

# Include functions needed for modeling
source("P:/A335/Common/SAE/0_Small Area Models - R code.R"); 

# Read the direct estimates for hypertension
estimates = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/State_Age_Direct_Estimates.xlsx",
         sheet="ESTIMATES") 
names(estimates) = toupper(names(estimates)) # Capitalize all column names

# Save the crude estimates
estimates_crude = estimates %>% filter(EST_TYPE == "crude") %>% 
              dplyr::select(-CV, -STATE)
summary(estimates_crude)

# Identify any rows with sample size < 15 then suppress until cumulative 
# N_SAMP >= 15 (we will next suppress all rows < 25)
estimates_crude <- estimates_crude %>%
  group_by(YEAR_MONTH, CONDITION, STATE_FIPS) %>%
  arrange(N_SAMP, AGEC, .by_group = TRUE) %>%
  mutate(
    NEED_SUPP = any(N_SAMP < 15),
    
    CUM_N = cumsum(N_SAMP),
    
    SUPPRESS = NEED_SUPP & lag(CUM_N, default = 0) < 15
  ) %>%
  ungroup()

# Check
summary(estimates_crude %>% filter(N_SAMP < n_supp | SUPPRESS==1))
summary(estimates_crude %>% filter(N_SAMP >= n_supp & SUPPRESS==0))

# Suppress the crude estimates if sample size < n_supp
estimates_crude = estimates_crude %>% 
  rename(N_SAMP_OLD=N_SAMP, SE_OLD=SE, PREVALENCE_OLD=PREVALENCE) %>%
  mutate(PREVALENCE = if_else(N_SAMP_OLD < n_supp | SUPPRESS==1, NA, PREVALENCE_OLD),
         SE         = if_else(N_SAMP_OLD < n_supp | SUPPRESS==1, NA, SE_OLD),
         N_SAMP     = if_else(N_SAMP_OLD < n_supp | SUPPRESS==1, NA, N_SAMP_OLD)) %>%
  dplyr::select(-PREVALENCE_OLD, -SE_OLD, -N_SAMP_OLD, -NEED_SUPP, -CUM_N)

summary(estimates_crude %>% filter(N_SAMP >= n_supp & SUPPRESS==0))
summary(estimates_crude %>% filter(is.na(N_SAMP)))
summary(estimates_crude)

estimates_crude = estimates_crude %>% dplyr::select(-SUPPRESS)

# Subset to weighted estimates
estimates = estimates %>% filter(EST_TYPE == "modeled") %>% dplyr::select(-STATE)
summary(estimates)

# Identify any rows with sample size < 15 then suppress until cumulative 
# N_SAMP >= 15 (we will next suppress all rows < 25)
estimates <- estimates %>%
  group_by(YEAR_MONTH, CONDITION, STATE_FIPS) %>%
  arrange(N_SAMP, AGEC, .by_group = TRUE) %>%
  mutate(
    NEED_SUPP = any(N_SAMP < 15),
    
    CUM_N = cumsum(N_SAMP),
    
    SUPPRESS = NEED_SUPP & lag(CUM_N, default = 0) < 15
  ) %>%
  ungroup()

# Check
summary(estimates %>% filter(N_SAMP < n_supp | SUPPRESS==1))
summary(estimates %>% filter(N_SAMP >= n_supp & SUPPRESS==0))

# We won't be modeling data when sample size < n_supp OR SUPPRESS==1 
estimates_rest = estimates %>% filter(N_SAMP < n_supp | SUPPRESS == 1) %>%
  dplyr::select(-CV, -NEED_SUPP, -CUM_N, -SUPPRESS) %>%
  mutate(PREVALENCE=as.numeric(NA), SE=as.numeric(NA), N_SAMP=as.numeric(NA))
summary(estimates_rest)

estimates = estimates %>% filter(N_SAMP >= n_supp & SUPPRESS==0) %>%
      dplyr::select(-NEED_SUPP, -CUM_N, -SUPPRESS)
summary(estimates)

# Initial smooth variance estimate
# Since some areas have extremely large sample sizes, reduce the influence for these areas (within each subgroup)
trim.n = estimates %>% group_by(YEAR_MONTH, EST_TYPE, CONDITION, AGEC) %>%
            summarise(TRIM_N_SAMP = quantile(N_SAMP, trim.q), .groups = "drop")

estimates = left_join(estimates, trim.n, by=c("YEAR_MONTH", "EST_TYPE", "CONDITION", "AGEC")) %>%
      mutate(N_SAMP_ADJ = if_else(N_SAMP > TRIM_N_SAMP, TRIM_N_SAMP, N_SAMP)) %>%
      dplyr::select(-TRIM_N_SAMP)

estimates = estimates %>% 
              mutate(PREVALENCE_DIRECT = PREVALENCE, PREVALENCE = PREVALENCE/100,
                     PREVALENCE_BND = pmin(pmax(PREVALENCE, 0.05), 0.95),
                     SE_INIT = if_else(EST_TYPE == "modeled",
                       sqrt(PREVALENCE_BND*(1-PREVALENCE_BND)*(1+(CV/100)^2)/N_SAMP_ADJ), 
                            NA)) %>%
              dplyr::select(-PREVALENCE_BND)
summary(estimates)

# 2023 BRFSS estimates
BRFSS23 = read_excel("P:/A335/Common/SAE/External Estimates/State/BRFSS2023.xlsx")  
names(BRFSS23) = toupper(names(BRFSS23)) # Capitalize all column names
BRFSS23 = BRFSS23 %>% mutate(CONDITION = "HTN")

# 2021 BRFSS estimates
BRFSS21 = read_excel("P:/A335/Common/SAE/External Estimates/State/BRFSS2021.xlsx")  
names(BRFSS21) = toupper(names(BRFSS21)) # Capitalize all column names
BRFSS21 = BRFSS21 %>% mutate(CONDITION = "HTN")

# Covariates
covariates = read_excel("P:/A335/Common/SAE/Covariates/State_Age_Covariates.xlsx")  
names(covariates) = toupper(names(covariates)) # Capitalize all column names

# Check the covariates
str(covariates)

covariates$ACS_PCT_DISABLED <- as.numeric(covariates$ACS_PCT_DISABLED)

# Census Region lookup
region_lookup <- list(
  #Northeast = c("CT","ME","MA","NH","RI","VT",  # New England
  #              "NJ","NY","PA"),                # Middle Atlantic
  Midwest   = c("IL","IN","MI","OH","WI",       # East North Central
                "IA","KS","MN","MO","NE","ND","SD"), # West North Central
  South     = c("DE","FL","GA","MD","NC","SC","VA","WV","DC", # South Atlantic
                "AL","KY","MS","TN",                             # East South Central
                "AR","LA","OK","TX"),                            # West South Central
  West      = c("AZ","CO","ID","MT","NV","NM","UT","WY",  # Mountain
                "AK","CA","HI","OR","WA")                 # Pacific
)

# Create region indicator (one-hot) columns: REG_Northeast, REG_Midwest, REG_South, REG_West
for (reg in names(region_lookup)) {
  covariates[[paste0("REG_", reg)]] <- ifelse(
    covariates$STATE %in% region_lookup[[reg]], 1, 0
  )
}


# Create dummies for each subgroup
covariates <- dummy_cols(covariates, 
                         select_columns = "AGEC", 
                         remove_first_dummy = FALSE, 
                         remove_selected_columns = FALSE)

# clean names
names(covariates) <- gsub("-", "_", names(covariates))
names(covariates) <- gsub("AGEC_", "AGE_", names(covariates))

# Check
covariates %>% group_by(AGEC, AGE_20_24, AGE_25_29, AGE_30_34, AGE_35_44,
                        AGE_45_54, AGE_55_64, AGE_65_74, AGE_75_84) %>% count()

# Variable names for direct estimate and covariates
IV = c("PREVALENCE")
variables = c("P_FOODSTAMP", "P_OWNER", 
              "P_COLLEGE", #"P_HS",
              "P_NOHS", "P_UNEMP",                
              "P_UNINS",  "P_HISPANIC",             
              "P_WHITE", "P_BLACK",               
              "P_ASIAN",  "P_FEMALE",
              "P_POVERTY", "P_BROADBAND",            
              "HH_INCOME",  "FOOD_INSECURITY",                
              "MORT_HEART_DISEASE", "MORT_STROKE",
              "MORT_DIABETES", "MORT_KIDNEY_DISEASE",
              "PRIMARY_CARE_PROVIDERS", "WALK", 
              "ACS_PCT_SHCB", "ACS_PCT_DISABLED",               
              "REG_Midwest", "REG_South", "REG_West",
              "AGE_25_29", "AGE_30_34", "AGE_35_44", "AGE_45_54", "AGE_55_64",
              "AGE_65_74", "AGE_75_84"
              )

# Create a data frame to save model estimates
estimates_weighted = data.frame()

# Loop through all the months
months = unique(estimates$YEAR_MONTH)
num.months = length(months) # Number of months

# Save info for purposes of checking

summary_htn <- data.frame(
  num_cov = numeric(),
  sigma = numeric(),
  convergence = numeric(),
  message = character(),
  min.weight = numeric(),
  median.weight = numeric(),
  max.weight = numeric(),
  min.diff = numeric(),
  median.diff = numeric(),
  max.diff = numeric(),
  min.ratio = numeric(),
  median.ratio = numeric(),
  max.ratio = numeric()
)

summary_htnc <- data.frame(
  num_cov = numeric(),
  sigma = numeric(),
  convergence = numeric(),
  message = character(),
  min.weight = numeric(),
  median.weight = numeric(),
  max.weight = numeric(),
  min.diff = numeric(),
  median.diff = numeric(),
  max.diff = numeric(),
  min.ratio = numeric(),
  median.ratio = numeric(),
  max.ratio = numeric()
)

pdf("State_Age_Model_Plots.pdf")
sink("State_Age_Model_Output.txt")

for (i in 1:num.months) {

print(months[i])
cat("\n Hypertension \n")

# First model hypertension
# Merge covariate data 
estimates_h = full_join(estimates %>% 
                  filter(YEAR_MONTH==months[i] & CONDITION=="HTN" &  EST_TYPE=="modeled"), 
                        covariates, by=c("STATE_FIPS","AGEC"))
estimates_h = estimates_h %>% 
                  mutate(YEAR_MONTH=months[i], EST_TYPE="modeled", 
                         CONDITION="HTN") %>% arrange(STATE_FIPS, AGEC)

estimates_cor = estimates_h %>% filter(N_SAMP >=n_supp & is.na(N_SAMP)==F) # Used for variable selection

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# GVF standard errors
estimates_cor <- estimates_cor %>%
  mutate(
    GVF_SE = GVF.smooth(
      n = N_SAMP_ADJ,
      p = pmin(pmax(PREVALENCE, 0.05), 0.95),
      y = SE_INIT
    )
  )

# Model selection
var = unlist(estimates_cor$GVF_SE)^2

# Start with the null model (intercept [Northeast Region] + Region indicators)
null_model <- glm(PREVALENCE ~ REG_Midwest + REG_South + REG_West + 
                    AGE_25_29 + AGE_30_34 + AGE_35_44 + AGE_45_54 + 
                    AGE_55_64 + AGE_65_74 + AGE_75_84, 
                  data = estimates_cor[,c(IV,variables)],
                  weights = 1/var,
                  family = gaussian()
)
# Full model with all predictors
full_model <- glm(PREVALENCE ~ ., data = estimates_cor[,c(IV,variables)],
                  weights = 1/var,
                  family = gaussian()
)

AIC.selection = step(null_model, scope = list(lower = null_model, upper = full_model), 
                     direction="forward", scale=0, k=4, trace = 0)
cat("\n Model Selection \n")
print(summary(AIC.selection))
final.variables = names(AIC.selection$coef)[-1]

# GVF standard errors
estimates_model <- estimates_model %>%
  mutate(
    GVF_SE = GVF.smooth(
      n = N_SAMP_ADJ,
      p = pmin(pmax(PREVALENCE, 0.05), 0.95),
      y = SE_INIT
    )
  )

# Parameters
m = dim(estimates_h)[1]; 		# Number of counties
covariate.names = c("INTERCEPT", final.variables)
num.cov = length(covariate.names) # total number of covariates including intercept

# Create a matrix of covariates for model Selection
X.pop = matrix(nrow=m, ncol=num.cov, dimnames=list(NULL,covariate.names))   

X.pop[,1] = 1; # Overall intercept term

for (j in 1:(num.cov-1)) {
  X.pop[,1+j] = unlist(estimates_h[final.variables[j]])
}

X = X.pop[is.na(estimates_h$N_SAMP)==F,]
  
# Model fit
try_nlminb <- function(start_val) {
  nlminb(
    start     = start_val,
    objective = sigma.FH,
    lower     = 1e-5,
    upper     = Inf,
    y   = estimates_model$PREVALENCE,
    psi = estimates_model$GVF_SE^2,
    X   = X
  )
}

# Build up to 5 sensible starting values from psi:
candidate_starts <- c(
  median(estimates_model$GVF_SE^2, na.rm = TRUE),
  mean(estimates_model$GVF_SE^2, na.rm = TRUE),
  as.numeric(quantile(estimates_model$GVF_SE^2, probs = c(0.25, 0.75), na.rm = TRUE)),
  max(1e-3, median(estimates_model$GVF_SE^2, na.rm = TRUE) / 2)  # a smaller "safety" start
)

temp <- NULL
last_error <- NULL
for (s in candidate_starts) {
  fit <- tryCatch(
    try_nlminb(s),
    error = function(e) { last_error <<- e; NULL }
  )
  if (!is.null(fit)) {
    # nlminb "success" iff convergence == 0
    if (fit$convergence == 0) {
      temp <- fit
      break
    } else {
      last_error <- sprintf("Non-convergence with start=%.6g (code=%s)", s, fit$convergence)
    }
  }
}

if (is.null(temp)) {
  stop("All starting values failed. Last issue: ",
       if (inherits(last_error, "error")) conditionMessage(last_error) else as.character(last_error))
}

# 'temp' now holds the converged nlminb() result

cat("\n Convergence \n")
print(temp)
cat("\n Weight for the Direct Estimate \n")
print(summary(temp$par/(estimates_model$GVF_SE^2 + temp$par)))

sigma.hat = temp$par;
beta.hat = beta.FH(sigma=sigma.hat, y=estimates_model$PREVALENCE, 
                   psi=estimates_model$GVF_SE^2, X=X)

cat("\n Parameter estimates \n")
print(test.FH(beta=beta.hat, sigma=sigma.hat, X=X, psi=estimates_model$GVF_SE^2))

# Flag for counties with direct estimates
Dir_Est_Flag = 1 - is.na(estimates_h$N_SAMP) 

# EBLUP
theta.curr = EBLUP.FH(sigma=sigma.hat, beta=beta.hat, X.pop=X.pop, 
                      y=estimates_model$PREVALENCE, psi=estimates_model$GVF_SE^2, 
                      Dir_Est_Flag=Dir_Est_Flag)
theta.curr = ifelse(theta.curr<0, 0, 
                    ifelse(theta.curr>1, 1, theta.curr)) # Truncate if predicted value < 0

# MSE
theta.MSE = MSE.FH(sigma=sigma.hat, X.pop=X.pop, psi=estimates_model$GVF_SE^2, 
                   Dir_Est_Flag=Dir_Est_Flag)

estimates_h$PREVALENCE = 100*theta.curr # Append onto input data
estimates_h$SE = 100*sqrt(theta.MSE)

# Plots
plot(estimates_h$PREVALENCE, estimates_h$PREVALENCE_DIRECT, xlab="Model", ylab="Direct",
     main="Hypertension: Direct vs Model")
abline(0,1)

plot(ifelse(estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]>10000, 10000,
              estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]), 
     estimates_h$PREVALENCE[is.na(estimates_h$N_SAMP)==F] - 
          estimates_h$PREVALENCE_DIRECT[is.na(estimates_h$N_SAMP)==F],
     xlab="Number of patients in state", 
     ylab="Difference between modeled and weighted hypertension prevalance",
     main="Hypertension: Difference in estimates by number of patients")

cat("\n Difference between model and direct \n")
print(summary(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT))

cat("\n Ratio of the SE's \n")
print(summary(100*estimates_h$SE_INIT / estimates_h$SE))

estimates_weighted = rbind(estimates_weighted, 
                    estimates_h %>% dplyr::select(YEAR_MONTH, STATE_FIPS, PREVALENCE,
                        EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, STATE, 
                        AGEC, POPN_20_84))

# Save all info

summary_htn[i, ] <- list(
  num_cov = num.cov,
  sigma = sigma.hat,
  convergence = temp$convergence,
  message = temp$message,
  min.weight = min(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  median.weight = median(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  max.weight = max(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  min.diff = min(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  median.diff = median(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  max.diff = max(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  min.ratio = min(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T),
  median.ratio = median(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T),
  max.ratio = max(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T)
)

# Next model hypertension control

cat("\n Hypertension Control \n")

# Merge covariate data 
estimates_h = full_join(estimates  %>% 
              filter(YEAR_MONTH==months[i] & CONDITION=="HTN-C" & EST_TYPE=="modeled"), 
                        covariates, by=c("STATE_FIPS","AGEC"))
estimates_h = estimates_h %>% 
  mutate(YEAR_MONTH=months[i], EST_TYPE="modeled", 
         CONDITION="HTN-C") %>% arrange(STATE_FIPS, AGEC)

estimates_cor = estimates_h %>% filter(N_SAMP >=n_supp & is.na(N_SAMP)==F) # Used for deriving correlations

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# GVF standard errors
estimates_cor <- estimates_cor %>%
  mutate(
    GVF_SE = GVF.smooth(
      n = N_SAMP_ADJ,
      p = pmin(pmax(PREVALENCE, 0.05), 0.95),
      y = SE_INIT
    )
  )

# Model selection
var = unlist(estimates_cor$GVF_SE)^2

# Start with the null model (intercept [Northeast Region] + Region indicators)
null_model <- glm(PREVALENCE ~ REG_Midwest + REG_South + REG_West + 
                    AGE_25_29 + AGE_30_34 + AGE_35_44 + AGE_45_54 + 
                    AGE_55_64 + AGE_65_74 + AGE_75_84, 
                  data = estimates_cor[,c(IV,variables)],
                  weights = 1/var,
                  family = gaussian()
)
# Full model with all predictors
full_model <- glm(PREVALENCE ~ ., data = estimates_cor[,c(IV,variables)],
                  weights = 1/var,
                  family = gaussian()
)

AIC.selection = step(null_model, scope = list(lower = null_model, upper = full_model), 
                     direction="forward", scale=0, k=4, trace = 0)
cat("\n Model Selection \n")
print(summary(AIC.selection))
final.variables = names(AIC.selection$coef)[-1]

# GVF standard errors
estimates_model <- estimates_model %>%
  mutate(
    GVF_SE = GVF.smooth(
      n = N_SAMP_ADJ,
      p = pmin(pmax(PREVALENCE, 0.05), 0.95),
      y = SE_INIT
    )
  )

# Parameters
m = dim(estimates_h)[1]; 		# Number of counties
covariate.names = c("INTERCEPT", final.variables)
num.cov = length(covariate.names) # total number of covariates including intercept

# Create a matrix of covariates for model Selection
X.pop = matrix(nrow=m, ncol=num.cov, dimnames=list(NULL,covariate.names))   

X.pop[,1] = 1; # Overall intercept term

for (j in 1:(num.cov-1)) {
  X.pop[,1+j] = unlist(estimates_h[final.variables[j]])
}

X = X.pop[is.na(estimates_h$N_SAMP)==F,]

# Model fit
try_nlminb <- function(start_val) {
  nlminb(
    start     = start_val,
    objective = sigma.FH,
    lower     = 1e-5,
    upper     = Inf,
    y   = estimates_model$PREVALENCE,
    psi = estimates_model$GVF_SE^2,
    X   = X
  )
}

# Build up to 5 sensible starting values from psi:
candidate_starts <- c(
  median(estimates_model$GVF_SE^2, na.rm = TRUE),
  mean(estimates_model$GVF_SE^2, na.rm = TRUE),
  as.numeric(quantile(estimates_model$GVF_SE^2, probs = c(0.25, 0.75), na.rm = TRUE)),
  max(1e-3, median(estimates_model$GVF_SE^2, na.rm = TRUE) / 2)  # a smaller "safety" start
)

temp <- NULL
last_error <- NULL
for (s in candidate_starts) {
  fit <- tryCatch(
    try_nlminb(s),
    error = function(e) { last_error <<- e; NULL }
  )
  if (!is.null(fit)) {
    # nlminb "success" iff convergence == 0
    if (fit$convergence == 0) {
      temp <- fit
      break
    } else {
      last_error <- sprintf("Non-convergence with start=%.6g (code=%s)", s, fit$convergence)
    }
  }
}

if (is.null(temp)) {
  stop("All starting values failed. Last issue: ",
       if (inherits(last_error, "error")) conditionMessage(last_error) else as.character(last_error))
}

# 'temp' now holds the converged nlminb() result

cat("\n Convergence \n")
print(temp)
cat("\n Weight for the Direct Estimate \n")
print(summary(temp$par/(estimates_model$GVF_SE^2 + temp$par)))

sigma.hat = temp$par;
beta.hat = beta.FH(sigma=sigma.hat, y=estimates_model$PREVALENCE, 
                   psi=estimates_model$GVF_SE^2, X=X)

cat("\n Parameter estimates \n")
print(test.FH(beta=beta.hat, sigma=sigma.hat, X=X, psi=estimates_model$GVF_SE^2))

# Flag for counties with direct estimates
Dir_Est_Flag = 1 - is.na(estimates_h$N_SAMP)

# EBLUP
theta.curr = EBLUP.FH(sigma=sigma.hat, beta=beta.hat, X.pop=X.pop, 
                      y=estimates_model$PREVALENCE, psi=estimates_model$GVF_SE^2, 
                      Dir_Est_Flag=Dir_Est_Flag)
theta.curr = ifelse(theta.curr<0, 0, 
                    ifelse(theta.curr>1, 1, theta.curr)) # Truncate if predicted value < 0

# MSE
theta.MSE = MSE.FH(sigma=sigma.hat, X.pop=X.pop, psi=estimates_model$GVF_SE^2, 
                   Dir_Est_Flag=Dir_Est_Flag)

estimates_h$PREVALENCE = 100*theta.curr # Append onto input data
estimates_h$SE = 100*sqrt(theta.MSE)

# Plots
plot(estimates_h$PREVALENCE, estimates_h$PREVALENCE_DIRECT, xlab="Model", ylab="Direct",
     main="Hypertension Control: Direct vs Model")
abline(0,1)

plot(ifelse(estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]>10000, 10000,
            estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]), 
     estimates_h$PREVALENCE[is.na(estimates_h$N_SAMP)==F] - 
       estimates_h$PREVALENCE_DIRECT[is.na(estimates_h$N_SAMP)==F],
     xlab="Number of patients in state", 
     ylab="Difference between modeled and weighted hypertension prevalance",
     main="Hypertension Control: Difference in estimates vs number of patients")

cat("\n Difference between model and direct \n")
print(summary(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT))

cat("\n Ratio of the SE's \n")
print(summary(100*estimates_h$SE_INIT / estimates_h$SE))

estimates_weighted = rbind(estimates_weighted, 
              estimates_h %>% dplyr::select(YEAR_MONTH, STATE_FIPS, PREVALENCE,
                        EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, STATE, 
                        AGEC, POPN_20_84))

summary_htnc[i, ] <- list(
  num_cov = num.cov,
  sigma = sigma.hat,
  convergence = temp$convergence,
  message = temp$message,
  min.weight = min(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  median.weight = median(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  max.weight = max(temp$par/(estimates_model$GVF_SE^2 + temp$par)),
  min.diff = min(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  median.diff = median(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  max.diff = max(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT, na.rm=T),
  min.ratio = min(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T),
  median.ratio = median(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T),
  max.ratio = max(100*estimates_h$SE_INIT / estimates_h$SE, na.rm=T)
)

cat("\n End of iteration \n\n")

}

sink()
dev.off()

# Checks
summary(summary_htn)
summary_htn$message
summary(summary_htnc)
summary_htnc$message

# State comparison

state = estimates_weighted %>% group_by(CONDITION, STATE, AGEC) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP), .groups = "drop")

state_excl2019 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) != "2019") %>%
  group_by(CONDITION, STATE, AGEC) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP), .groups = "drop")

# State comparison

state2 = estimates_weighted %>% group_by(CONDITION, STATE, YEAR_MONTH) %>% 
  summarize(PREVALENCE_MODEL = weighted.mean(PREVALENCE, POPN_20_84), 
            PREVALENCE_DIRECT = weighted.mean(PREVALENCE_DIRECT, POPN_20_84, na.rm=T), .groups = "drop")

state2 = full_join(full_join(state2, 
      BRFSS21 %>% dplyr::select(STATE, P_BRFSS, CONDITION) %>% rename(P_BRFSS21=P_BRFSS)), 
      BRFSS23 %>% dplyr::select(STATE, P_BRFSS, CONDITION) %>% rename(P_BRFSS23=P_BRFSS)) 

# Correlations
state_correlation_htn = state2 %>% 
      filter(CONDITION=="HTN") %>% group_by(YEAR_MONTH) %>% 
          summarise(COR_MODEL_BRFSS21=cor(P_BRFSS21, PREVALENCE_MODEL, use="complete.obs"),
                    COR_MODEL_BRFSS23=cor(P_BRFSS23, PREVALENCE_MODEL, use="complete.obs"),
                    COR_MODEL_DIRECT=cor(PREVALENCE_DIRECT, PREVALENCE_MODEL, use="complete.obs"),
                    COR_DIRECT_BRFSS21=cor(P_BRFSS21, PREVALENCE_DIRECT, use="complete.obs"),
                    COR_DIRECT_BRFSS23=cor(P_BRFSS23, PREVALENCE_DIRECT, use="complete.obs")) 

state_correlation_htnc = state2 %>% 
  filter(CONDITION=="HTN-C") %>% group_by(YEAR_MONTH) %>% 
  summarise(COR_MODEL_DIRECT=cor(PREVALENCE_DIRECT, PREVALENCE_MODEL, use="complete.obs")) 

# National estimates

national = estimates_weighted %>% group_by(CONDITION, YEAR_MONTH) %>% 
    summarize(PREVALENCE_MODEL = weighted.mean(PREVALENCE, POPN_20_84),
              PREVALENCE_DIRECT = weighted.mean(PREVALENCE_DIRECT, POPN_20_84, na.rm=T), 
              .groups = "drop")

# Export the summary files

sheets = list("State" = state,
              "State_excl2019" = state_excl2019,
              "State Comp" = state2,
              "Htn Corr" = state_correlation_htn,
              "Htn-C Corr" = state_correlation_htnc,
              "National" = national
) 
write.xlsx(sheets, 'State Age Model Output.xlsx')

# Export the full data

write.xlsx(estimates_weighted, "State_Age_Estimates_All.xlsx",  sep=",", rowNames=F)

# Create the final data file

# Limit to month/state/indicator combinations with non-missing patients
# Suppress estimates with  CV < 0.3

estimates_weighted = estimates_weighted %>% filter(is.na(N_SAMP)==F) %>%
            dplyr::select(-PREVALENCE_DIRECT, -STATE, -POPN_20_84) %>%
            mutate(CV = SE/PREVALENCE, SUPPRESS = if_else(CV >= 0.3, 1, 0)) %>%
            rename(N_SAMP_OLD = N_SAMP, PREVALENCE_OLD = PREVALENCE, SE_OLD = SE) %>%
            mutate(N_SAMP = if_else(SUPPRESS == 1, NA, N_SAMP_OLD),
                   PREVALENCE = if_else(SUPPRESS == 1, NA, PREVALENCE_OLD),
                   SE = if_else(SUPPRESS == 1, NA, SE_OLD)) %>%
            dplyr::select(-N_SAMP_OLD, -PREVALENCE_OLD, -SE_OLD)

summary(estimates_weighted)
summary(estimates_weighted %>% filter(CV >= 0.3))
summary(estimates_weighted %>% filter(CV < 0.3))

# Suppressed estimates -- need these to suppress crude
estimates_suppressed = estimates_weighted %>% filter(SUPPRESS == 1) %>% 
                dplyr::select(-CV)
summary(estimates_suppressed)

estimates_weighted = estimates_weighted %>% filter(SUPPRESS == 0) %>%
  dplyr::select(-CV, -SUPPRESS)
summary(estimates_weighted)

# Append all the suppressed combinations
estimates_weighted = full_join(estimates_weighted, 
                      estimates_crude %>% 
                        dplyr::select(YEAR_MONTH, STATE_FIPS, AGEC, CONDITION)) %>%
                      mutate(EST_TYPE = "modeled")

summary(estimates_weighted)
unique(estimates_weighted$YEAR_MONTH)
unique(estimates_weighted$STATE_FIPS)
unique(estimates_weighted$AGEC)
unique(estimates_weighted$EST_TYPE)
unique(estimates_weighted$CONDITION)

# Suppress crude when CV >= 0.3
estimates_crude = left_join(estimates_crude, estimates_suppressed %>% 
                dplyr::select(YEAR_MONTH, STATE_FIPS, AGEC, CONDITION, SUPPRESS)) %>%
  rename(N_SAMP_OLD = N_SAMP, PREVALENCE_OLD = PREVALENCE, SE_OLD = SE) %>%
  mutate(N_SAMP = if_else(is.na(SUPPRESS) == F, NA, N_SAMP_OLD),
         PREVALENCE = if_else(is.na(SUPPRESS) == F, NA, PREVALENCE_OLD),
         SE = if_else(is.na(SUPPRESS) == F, NA, SE_OLD)) %>%
  dplyr::select(-N_SAMP_OLD, -PREVALENCE_OLD, -SE_OLD)

summary(estimates_crude)
summary(estimates_crude %>% filter(SUPPRESS==1))
summary(estimates_crude %>% filter(is.na(SUPPRESS)))

estimates_crude = estimates_crude %>% dplyr::select(-SUPPRESS)

# Final data file
estimates_final = rbind(estimates_weighted, estimates_crude) %>% 
                    rename(NPATS = N_SAMP) %>%
                    arrange(EST_TYPE, CONDITION, YEAR_MONTH, STATE_FIPS, AGEC)
  
summary(estimates_final)
unique(estimates_final$YEAR_MONTH)
unique(estimates_final$STATE_FIPS)
unique(estimates_final$EST_TYPE)
unique(estimates_final$CONDITION)

# Export data

write.xlsx(estimates_final, "State_Age_Estimates_Modeled.xlsx",  sep=",", rowNames=F)

