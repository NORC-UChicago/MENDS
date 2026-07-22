
# Programmer: N. Ganesh
# Date: 03/04/2025

# install.packages("dplyr")

rm(list=ls()) # Clear work space

library(openxlsx)
library(readxl)
library(dplyr)
library(MASS)
library(leaps)

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
estimates1 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2019_2020") 
estimates2 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2021_2022") 
estimates3 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2023_2024") 
estimates4 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2025") 
estimates = rbind(estimates1, estimates2, estimates3, estimates4) %>% 
  dplyr::select(-file_flag)
rm(estimates1, estimates2, estimates3, estimates4)

names(estimates) = toupper(names(estimates)) # Capitalize all column names
summary(estimates)

# Save the crude estimates
estimates1 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2019_2020") 
estimates2 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2021_2022") 
estimates3 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2023_2024") 
estimates4 = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2025") 
estimates_crude = rbind(estimates1, estimates2, estimates3, estimates4) %>% 
        dplyr::select(-file_flag)
rm(estimates1, estimates2, estimates3, estimates4)

names(estimates_crude) = toupper(names(estimates_crude)) # Capitalize all column names
summary(estimates_crude)

crosswalk = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/State_Direct_Estimates.xlsx") 
names(crosswalk) = toupper(names(crosswalk)) # Capitalize all column names
crosswalk = crosswalk %>% group_by(STATE, STATE_FIPS) %>% count()

estimates = left_join(estimates, crosswalk %>% dplyr::select(STATE, STATE_FIPS))
dim(estimates)

estimates = estimates %>% dplyr::select(-STATE)
dim(estimates)

estimates_crude = left_join(estimates_crude, 
                            crosswalk %>% dplyr::select(STATE, STATE_FIPS))
dim(estimates_crude)

estimates_crude = estimates_crude %>% dplyr::select(-STATE,-STATE_FIPS,-CV)
dim(estimates_crude)

summary(estimates_crude %>% filter(N_SAMP >= n_supp))

# Suppress the crude estimates if sample size < n_supp
estimates_crude = estimates_crude %>% 
  rename(N_SAMP_OLD=N_SAMP, SE_OLD=SE, PREVALENCE_OLD=PREVALENCE) %>%
  mutate(PREVALENCE = if_else(N_SAMP_OLD < n_supp, NA, PREVALENCE_OLD),
         SE         = if_else(N_SAMP_OLD < n_supp, NA, SE_OLD),
         N_SAMP     = if_else(N_SAMP_OLD < n_supp, NA, N_SAMP_OLD)) %>%
  dplyr::select(-PREVALENCE_OLD, -SE_OLD, -N_SAMP_OLD)

summary(estimates_crude %>% filter(N_SAMP >= n_supp))
summary(estimates_crude %>% filter(is.na(N_SAMP)))
summary(estimates_crude)

# We won't be modeling data when sample size < n_supp -- put these aside & suppress data
estimates_rest = estimates %>% filter(N_SAMP < n_supp) %>%
  dplyr::select(-CV, -STATE_FIPS) %>%
  mutate(PREVALENCE=as.numeric(NA), SE=as.numeric(NA), N_SAMP=as.numeric(NA))
summary(estimates_rest)

estimates = estimates %>% filter(N_SAMP >= n_supp)
summary(estimates)

# State-level estimates
state.estimates = read_excel("P:/A335/Common/SAE/Q3/HTN/Direct Estimates/State_Direct_Estimates.xlsx")  
names(state.estimates) = toupper(names(state.estimates)) # Capitalize all column names
# Only need the weighted estimates
state.estimates = state.estimates %>% filter(EST_TYPE == "modeled")

# Append state estimate to ZIP file
estimates = left_join(estimates, state.estimates %>% 
                        dplyr::select(YEAR_MONTH, CONDITION, EST_TYPE, STATE_FIPS, PREVALENCE) %>%
                              rename(STATE_PREVALENCE = PREVALENCE), 
                              by=c("YEAR_MONTH", "CONDITION", "EST_TYPE", "STATE_FIPS"))
summary(estimates)

# Initial smooth variance estimate
# Since some areas have extremely large sample sizes, reduce the influence for these areas
trim.n = estimates %>% group_by(YEAR_MONTH, CONDITION) %>%
  summarise(TRIM_N_SAMP = quantile(N_SAMP, trim.q), .groups = "drop")

estimates = left_join(estimates, trim.n, by=c("YEAR_MONTH", "CONDITION")) %>%
  mutate(N_SAMP_ADJ = if_else(N_SAMP > TRIM_N_SAMP, TRIM_N_SAMP, N_SAMP)) %>%
  dplyr::select(-TRIM_N_SAMP)

estimates = estimates %>% 
              mutate(PREVALENCE_DIRECT = PREVALENCE, PREVALENCE = PREVALENCE/100, 
                     STATE_PREVALENCE = STATE_PREVALENCE/100,
                     SE_INIT = if_else(EST_TYPE == "modeled",
                       sqrt(STATE_PREVALENCE*(1-STATE_PREVALENCE)*(1+(CV/100)^2)/N_SAMP_ADJ), NA))
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
covariates = read_excel("P:/A335/Common/SAE/Covariates/ZIP_Covariates_2026Q2.xlsx")  
names(covariates) = toupper(names(covariates)) # Capitalize all column names

# Census Division lookup
division_lookup <- list(
 # New_England        = c("CT","ME","MA","NH","RI","VT"),
 # Middle_Atlantic    = c("NJ","NY","PA"),
  East_North_Central = c("IL","IN","MI","OH","WI"),
  West_North_Central = c("IA","KS","MN","MO","NE","ND","SD"),
  South_Atlantic     = c("DE","FL","GA","MD","NC","SC","VA","WV","DC"),
  East_South_Central = c("AL","KY","MS","TN"),
  West_South_Central = c("AR","LA","OK","TX"),
  Mountain           = c("AZ","CO","ID","MT","NV","NM","UT","WY"),
  Pacific            = c("AK","CA","HI","OR","WA")
)

for(div in names(division_lookup)) {
  covariates[[paste0("DIV_", div)]] <- ifelse(
    covariates$STATE %in% division_lookup[[div]],
    1, 0
  )
}

# Variable names for direct estimate and covariates
IV = c("PREVALENCE")
variables = c("ACS_MED_HHINC",                  
              "ACS_UNEMPLOYMENT_RATE",           "ACS_PCT_NOHS",                   
              "ACS_PCT_HS",                      "ACS_PCT_COLLEGE",                
              "ACS_PCT_BROADBAND",               "ACS_PCT_UNINSURED",              
              "ACS_PCT_SHCB",                    "ACS_PCT_DISABLED",               
              "ACS_PCT_TANF",                    "ACS_PCT_FPL",                    
              "ACS_PCT_AGE15TO64",               "ACS_PCT_AGEOVER65",              
              "ACS_PCT_FEMALE",                  "ACS_PCT_WHITE",                  
              "ACS_PCT_AFAM",                    "ACS_PCT_HISP",                   
              "ACS_PCT_ASIAN",        
              "DIV_East_North_Central",          "DIV_West_North_Central",         
              "DIV_South_Atlantic",              "DIV_East_South_Central",         
              "DIV_West_South_Central",          "DIV_Mountain",
              "DIV_Pacific")

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

pdf("ZIP_Model_Plots.pdf")
sink("ZIP_Model_Output.txt")

for (i in 1:num.months) {

print(months[i])
cat("\n Hypertension \n")

# First model hypertension
# Merge covariate data and exclude direct estimates with NO matching ZIP in the covariate file
estimates_h = full_join(estimates %>% filter(YEAR_MONTH==months[i] & CONDITION=="HTN" & 
                                             EST_TYPE=="modeled"), 
                        covariates, by="ZIP") %>% filter(is.na(ACS_PCT_WHITE)==F)

estimates_h = estimates_h %>% 
                  mutate(YEAR_MONTH=months[i], EST_TYPE="modeled", 
                         CONDITION="HTN") %>% arrange(ZIP)

estimates_cor = estimates_h %>% filter(N_SAMP >=n_supp & is.na(N_SAMP)==F) # Used for variable selection

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# Model selection
var = unlist(estimates_cor$SE_INIT)^2

# Start with the null model (intercept [Northeast Region] + Region indicators)
null_model <- glm(PREVALENCE ~ DIV_East_North_Central + DIV_West_North_Central + 
                    DIV_South_Atlantic + DIV_East_South_Central + DIV_West_South_Central + 
                    DIV_Mountain + DIV_Pacific, 
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

# Keep only coefficients that are not NA
coef_vec <- coef(AIC.selection)
coef_vec <- coef_vec[!is.na(coef_vec)]

# Extract variable names (exclude intercept)
final.variables <- names(coef_vec)[-1]

# GVF standard errors
estimates_model = estimates_model %>% 
        mutate(GVF_SE = 
                 GVF.smooth(n=estimates_model$N_SAMP_ADJ, 
                            p=estimates_model$STATE_PREVALENCE, y=estimates_model$SE_INIT))

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

plot(ifelse(estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]>1000, 1000,
              estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]), 
     estimates_h$PREVALENCE[is.na(estimates_h$N_SAMP)==F] - 
          estimates_h$PREVALENCE_DIRECT[is.na(estimates_h$N_SAMP)==F],
     xlab="Number of patients in ZIP Code", 
     ylab="Difference between modeled and weighted hypertension prevalance",
     main="Hypertension: Difference in estimates by number of patients")

cat("\n Difference between model and direct \n")
print(summary(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT))

cat("\n Ratio of the SE's \n")
print(summary(100*estimates_h$SE_INIT / estimates_h$SE))

estimates_weighted = rbind(estimates_weighted, 
                    estimates_h %>% dplyr::select(YEAR_MONTH, ZIP, PREVALENCE,
                                  EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, 
                                  STATE, TOTAL_PERSON))

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

# Merge covariate data and exclude direct estimates with NO matching ZIP in the covariate file
estimates_h = full_join(estimates %>% filter(YEAR_MONTH==months[i] & CONDITION=="HTN-C" & 
                                               EST_TYPE=="modeled"), 
                        covariates, by="ZIP") %>% filter(is.na(ACS_PCT_WHITE)==F)

estimates_h = estimates_h %>% 
  mutate(YEAR_MONTH=months[i], EST_TYPE="modeled", 
         CONDITION="HTN-C") %>% arrange(ZIP)

estimates_cor = estimates_h %>% filter(N_SAMP >=n_supp & is.na(N_SAMP)==F) # Used for variable selection

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# Model selection
var = unlist(estimates_cor$SE_INIT)^2

# Start with the null model (intercept [Northeast Region] + Region indicators)
null_model <- glm(PREVALENCE ~ DIV_East_North_Central + DIV_West_North_Central + 
                    DIV_South_Atlantic + DIV_East_South_Central + DIV_West_South_Central + 
                    DIV_Mountain + DIV_Pacific, 
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

# Keep only coefficients that are not NA
coef_vec <- coef(AIC.selection)
coef_vec <- coef_vec[!is.na(coef_vec)]

# Extract variable names (exclude intercept)
final.variables <- names(coef_vec)[-1]

# GVF standard errors
estimates_model = estimates_model %>% 
        mutate(GVF_SE = 
                 GVF.smooth(n=estimates_model$N_SAMP_ADJ, 
                            p=estimates_model$STATE_PREVALENCE, y=estimates_model$SE_INIT))

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

plot(ifelse(estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]>1000, 1000,
            estimates_h$N_SAMP[is.na(estimates_h$N_SAMP)==F]), 
     estimates_h$PREVALENCE[is.na(estimates_h$N_SAMP)==F] - 
       estimates_h$PREVALENCE_DIRECT[is.na(estimates_h$N_SAMP)==F],
     xlab="Number of patients in ZIP", 
     ylab="Difference between modeled and weighted hypertension prevalance",
     main="Hypertension Control: Difference in estimates vs number of patients")

cat("\n Difference between model and direct \n")
print(summary(estimates_h$PREVALENCE - estimates_h$PREVALENCE_DIRECT))

cat("\n Ratio of the SE's \n")
print(summary(100*estimates_h$SE_INIT / estimates_h$SE))

estimates_weighted = rbind(estimates_weighted, 
              estimates_h %>% dplyr::select(YEAR_MONTH, ZIP, PREVALENCE,
                        EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, 
                        STATE, TOTAL_PERSON))

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

# ZIP comparison

zip = estimates_weighted %>% group_by(CONDITION, ZIP) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP), .groups = "drop")

zip_excl2019 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) != "2019") %>%
  group_by(CONDITION, ZIP) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP), .groups = "drop")

# State comparison

state = estimates_weighted %>% group_by(CONDITION, STATE, YEAR_MONTH) %>% 
  summarize(PREVALENCE_MODEL = weighted.mean(PREVALENCE, TOTAL_PERSON), .groups = "drop")

state = full_join(full_join(full_join(state, state.estimates %>% 
                    dplyr::select(YEAR_MONTH, CONDITION, STATE, PREVALENCE) %>%
                    rename(PREVALENCE_DIRECT = PREVALENCE)), 
      BRFSS21 %>% dplyr::select(STATE, P_BRFSS, CONDITION) %>% rename(P_BRFSS21=P_BRFSS)), 
      BRFSS23 %>% dplyr::select(STATE, P_BRFSS, CONDITION) %>% rename(P_BRFSS23=P_BRFSS)) 

# Correlations
state_correlation_htn = state %>% 
      filter(CONDITION=="HTN") %>% group_by(YEAR_MONTH) %>% 
          summarise(COR_MODEL_BRFSS21=cor(P_BRFSS21, PREVALENCE_MODEL, use="complete.obs"),
                    COR_MODEL_BRFSS23=cor(P_BRFSS23, PREVALENCE_MODEL, use="complete.obs"),
                    COR_MODEL_DIRECT=cor(PREVALENCE_DIRECT, PREVALENCE_MODEL, use="complete.obs"),
                    COR_DIRECT_BRFSS21=cor(P_BRFSS21, PREVALENCE_DIRECT, use="complete.obs"),
                    COR_DIRECT_BRFSS23=cor(P_BRFSS23, PREVALENCE_DIRECT, use="complete.obs")) 

state_correlation_htnc = state %>% 
  filter(CONDITION=="HTN-C") %>% group_by(YEAR_MONTH) %>% 
  summarise(COR_MODEL_DIRECT=cor(PREVALENCE_DIRECT, PREVALENCE_MODEL, use="complete.obs")) 

# National estimates

national = estimates_weighted %>% group_by(CONDITION, YEAR_MONTH) %>% 
    summarize(PREVALENCE_MODEL = weighted.mean(PREVALENCE, TOTAL_PERSON), .groups = "drop")

# Export the summary files

sheets = list("ZIP" = zip,
              "ZIP2019" = zip_excl2019,
              "State" = state,
              "Htn Corr" = state_correlation_htn,
              "Htn-C Corr" = state_correlation_htnc,
              "National" = national
) 
write.xlsx(sheets, 'ZIP Model Output.xlsx')

# Export the full data

estimates1 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2019"))
estimates2 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2020"))
estimates3 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2021"))
estimates4 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2022"))
estimates5 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2023"))
estimates6 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2024"))
estimates7 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2025"))

sheets = list("modeled_2019" = estimates1,
              "modeled_2020" = estimates2,
              "modeled_2021" = estimates3,
              "modeled_2022" = estimates4,
              "modeled_2023" = estimates5,
              "modeled_2024" = estimates6,
              "modeled_2025" = estimates7
) 
write.xlsx(sheets, 'ZIP_Estimates_All.xlsx')

# Create the final data file

# Limit to month/state/indicator combinations with n_supp+ patients
# Suppress estimates with CV < 0.3

estimates_weighted = estimates_weighted %>% filter(is.na(N_SAMP)==F) %>%
            dplyr::select(-PREVALENCE_DIRECT, -STATE) %>%
            mutate(CV = SE/PREVALENCE, SUPPRESS = if_else(CV >= 0.3, 1, 0)) %>%
            rename(N_SAMP_OLD = N_SAMP, PREVALENCE_OLD = PREVALENCE, SE_OLD = SE) %>%
            mutate(N_SAMP = if_else(SUPPRESS == 1, NA, N_SAMP_OLD),
                   PREVALENCE = if_else(SUPPRESS == 1, NA, PREVALENCE_OLD),
                   SE = if_else(SUPPRESS == 1, NA, SE_OLD)) %>%
            dplyr::select(-N_SAMP_OLD, -PREVALENCE_OLD, -SE_OLD)

summary(estimates_weighted)
summary(estimates_weighted %>% filter(CV >= 0.3))
summary(estimates_weighted %>% filter(CV < 0.3))

estimates_weighted = estimates_weighted %>% filter(SUPPRESS == 0) %>%
  dplyr::select(-CV, -SUPPRESS)
summary(estimates_weighted)

# Append all the suppressed combinations (includes ZIP Codes with NO ACS covariates)
estimates_weighted = full_join(estimates_weighted, 
                               estimates_crude %>% 
                                 dplyr::select(YEAR_MONTH, ZIP, CONDITION)) %>%
  mutate(EST_TYPE = "modeled")

summary(estimates_weighted)
unique(estimates_weighted$YEAR_MONTH)
unique(estimates_weighted$ZIP)
unique(estimates_weighted$EST_TYPE)
unique(estimates_weighted$CONDITION)

# ALL suppressed estimates (includes estimates that were suppressed as a result of not
# having ACS covariates)
estimates_suppressed = estimates_weighted %>% filter(is.na(N_SAMP)) %>%
                            mutate(SUPPRESS=1)
summary(estimates_suppressed)

# Suppress crude
estimates_crude = left_join(estimates_crude, estimates_suppressed %>% 
                              dplyr::select(YEAR_MONTH, ZIP, CONDITION, SUPPRESS)) %>%
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
estimates_final = rbind(estimates_weighted %>% dplyr::select(-TOTAL_PERSON), 
                        estimates_crude) %>% 
  rename(NPATS = N_SAMP) %>%
  arrange(EST_TYPE, CONDITION, YEAR_MONTH, ZIP)

summary(estimates_final)
unique(estimates_final$YEAR_MONTH)
unique(estimates_final$ZIP)
unique(estimates_final$EST_TYPE)
unique(estimates_final$CONDITION)

# Export data

# Export the full data

sheets = list("2019" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2019")),
              "2020" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2020")),
              "2021" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2021")),
              "2022" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2022")),
              "2023" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2023")),
              "2024" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2024")),
              "2025" = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2025"))
) 
write.xlsx(sheets, 'ZIP_Estimates_Modeled.xlsx',  sep=",", rowNames=F)

