
# Programmer: N. Ganesh
# Date: 03/04/2025

# install.packages("dplyr")

rm(list=ls()) # Clear work space

# Function to trim extreme design effects

# As covariates use 1/sqrt(sample size) and sqrt(p*(1-p))
# Use weighted LS with weights = sample size
# Function parameters: n=sample size, p=proportion, y=design-based standard error

GVF.smooth = function(n, p, y) {
  
  X = cbind(1, 1/sqrt(n), sqrt(p*(1-p)))
  W  = diag(sqrt(n))
  
  GVF.beta = c(solve(t(X) %*% W %*% X) %*% t(X) %*% W %*% y)
  
  print(GVF.beta)
  
  # Check regression estimates using WLS vs LS; also check R^2
  temp = lm(formula = y ~ X[,2] + X[,3])
  # print(summary(temp))
  
  plot(y ,c(X %*% GVF.beta), xlab="Design-based SE", ylab="GVF SE") 
  abline(0,1)
  
  
  pred_SE = c(X %*% GVF.beta)
  
  pred_SE_fix = ifelse(pred_SE <= 0, sqrt(0.005*0.995*2/n), pred_SE)
  
  return(pred_SE_fix)
}

library(openxlsx)
library(readxl)
library(dplyr)
library(MASS)
library(leaps)

# Set working directory
foldername = "Q1/Model Estimates";
path = paste0("P:/A154/Common/SAE/", foldername);
setwd(path);

# Include functions needed for modeling
source("P:/A154/Common/SAE/0_Small Area Models - R code.R"); 

# Read the direct estimates for hypertension
estimates1 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2019_2020") 
estimates2 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2021_2022") 
estimates3 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="modeled_2023_2024") 
estimates = rbind(estimates1, estimates2, estimates3) %>% dplyr::select(-file_flag)
rm(estimates1, estimates2, estimates3)

names(estimates) = toupper(names(estimates)) # Capitalize all column names
summary(estimates)

# Save the crude estimates
estimates1 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2019_2020") 
estimates2 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2021_2022") 
estimates3 = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/ZIP_Direct_Estimates.xlsx",
                        sheet="crude_2023_2024") 
estimates_crude = rbind(estimates1, estimates2, estimates3) %>% dplyr::select(-file_flag)
rm(estimates1, estimates2, estimates3)

names(estimates_crude) = toupper(names(estimates_crude)) # Capitalize all column names
summary(estimates_crude)

# Limit to the 22 states 
# AR, AZ, CA, CO, FL, HI, IL, IN, KY, LA, MA, MD, MS, NE, NJ, NY, OK, OR, TX, VA, WA, WY

crosswalk = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/State_Direct_Estimates.xlsx") 
names(crosswalk) = toupper(names(crosswalk)) # Capitalize all column names
crosswalk = crosswalk %>% group_by(STATE, STATE_FIPS) %>% count()

estimates = left_join(estimates, crosswalk %>% dplyr::select(STATE, STATE_FIPS))
dim(estimates)

estimates = estimates %>% 
  filter(STATE %in% c("AR", "AZ", "CA", "CO", "FL", "HI", "IL", "IN", "KY", "LA", "MA", 
                      "MD", "MS", "NE", "NJ", "NY", "OK", "OR", "TX", "VA", "WA", "WY")) %>%
  dplyr::select(-STATE)
dim(estimates)

estimates_crude = left_join(estimates_crude, 
                            crosswalk %>% dplyr::select(STATE, STATE_FIPS))
dim(estimates_crude)

estimates_crude = estimates_crude %>% 
  filter(STATE %in% c("AR", "AZ", "CA", "CO", "FL", "HI", "IL", "IN", "KY", "LA", "MA", 
                      "MD", "MS", "NE", "NJ", "NY", "OK", "OR", "TX", "VA", "WA", "WY")) %>%
  dplyr::select(-STATE,-STATE_FIPS,-CV)
dim(estimates_crude)

summary(estimates_crude %>% filter(N_SAMP >= 15))

# Suppress the crude estimates if sample size < 15
estimates_crude = estimates_crude %>% 
  rename(N_SAMP_OLD=N_SAMP, SE_OLD=SE, PREVALENCE_OLD=PREVALENCE) %>%
  mutate(PREVALENCE = if_else(N_SAMP_OLD < 15, NA, PREVALENCE_OLD),
         SE         = if_else(N_SAMP_OLD < 15, NA, SE_OLD),
         N_SAMP     = if_else(N_SAMP_OLD < 15, NA, N_SAMP_OLD)) %>%
  dplyr::select(-PREVALENCE_OLD, -SE_OLD, -N_SAMP_OLD)

summary(estimates_crude %>% filter(N_SAMP >= 15))
summary(estimates_crude %>% filter(is.na(N_SAMP)))
summary(estimates_crude)

# We won't be modeling data when sample size < 15 -- put these aside & suppress data
estimates_rest = estimates %>% filter(N_SAMP < 15) %>%
  dplyr::select(-CV, -STATE_FIPS) %>%
  mutate(PREVALENCE=as.numeric(NA), SE=as.numeric(NA), N_SAMP=as.numeric(NA))
summary(estimates_rest)

estimates = estimates %>% filter(N_SAMP >= 15)
summary(estimates)

# State-level estimates
state.estimates = read_excel("P:/A154/Common/SAE/Q1/Direct Estimates/State_Direct_Estimates.xlsx")  
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
estimates = estimates %>% 
              mutate(PREVALENCE_DIRECT = PREVALENCE, PREVALENCE = PREVALENCE/100, 
                     STATE_PREVALENCE = STATE_PREVALENCE/100,
                     SE_INIT = if_else(EST_TYPE == "modeled",
                       sqrt(STATE_PREVALENCE*(1-STATE_PREVALENCE)*(1+(CV/100)^2)/N_SAMP), NA))
summary(estimates)

# 2023 BRFSS estimates
BRFSS23 = read_excel("P:/A154/Common/SAE/Testing/BRFSS/BRFSS2023.xlsx")  
names(BRFSS23) = toupper(names(BRFSS23)) # Capitalize all column names
BRFSS23 = BRFSS23 %>% mutate(CONDITION = "HTN")

# 2021 BRFSS estimates
BRFSS21 = read_excel("P:/A154/Common/SAE/Testing/BRFSS/BRFSS2021.xlsx")  
names(BRFSS21) = toupper(names(BRFSS21)) # Capitalize all column names
BRFSS21 = BRFSS21 %>% mutate(CONDITION = "HTN")

# Covariates
covariates = read_excel("P:/A154/Common/SAE/Covariates/ZIP_Covariates.xlsx")  
names(covariates) = toupper(names(covariates)) # Capitalize all column names

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
              "ACS_PCT_ASIAN"                  )

# Create a data frame to save model estimates
estimates_weighted = data.frame()

# Loop through all the months
months = unique(estimates$YEAR_MONTH)
num.months = length(months) # Number of months

sink("ZIP_Model_Output_NEW.txt")

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

estimates_cor = estimates_h %>% filter(N_SAMP >=30 & is.na(N_SAMP)==F) # Used for variable selection

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# Compute the correlation of the IV by sample type with each covariate 
correlation = matrix(nrow=length(variables), ncol=1, 
                     dimnames = list(NULL,IV))

  for(j in 1:length(variables)) {
    correlation[j,1] = round(cor(x=estimates_cor[,IV],y=estimates_cor[,variables[j]], 
                                 use="complete.obs"),2)
  }

correlation = data.frame(VARIABLE=variables, correlation, SEL=0)
#print("Correlation")
#print(correlation)

# Model selection
# Start with the null model (intercept only)
null_model = lm(PREVALENCE ~ 1, data = estimates_cor[,c(IV,variables)])
# Full model with all predictors
full_model = lm(PREVALENCE ~ ., data = estimates_cor[,c(IV,variables)])

AIC.selection = step(null_model, scope = list(lower = null_model, upper = full_model), 
                     direction="forward", scale=0, k=3, trace = 0)

cat("\n Model Selection \n")
print(summary(AIC.selection))
final.variables = names(AIC.selection$coef)[-1]

# GVF standard errors
estimates_model = estimates_model %>% 
        mutate(GVF_SE = 
                 GVF.smooth(n=estimates_model$N_SAMP, 
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
temp = nlminb(start=median(estimates_model$GVF_SE^2), 
              obj=sigma.FH, lower=0.00001, upper=Inf, y=estimates_model$PREVALENCE, 
              psi=estimates_model$GVF_SE^2, X=X)
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
                                  EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, STATE))

# Next model hypertension control

cat("\n Hypertension Control \n")

# Merge covariate data and exclude direct estimates with NO matching ZIP in the covariate file
estimates_h = full_join(estimates %>% filter(YEAR_MONTH==months[i] & CONDITION=="HTN-C" & 
                                               EST_TYPE=="modeled"), 
                        covariates, by="ZIP") %>% filter(is.na(ACS_PCT_WHITE)==F)

estimates_h = estimates_h %>% 
  mutate(YEAR_MONTH=months[i], EST_TYPE="modeled", 
         CONDITION="HTN-C") %>% arrange(ZIP)

estimates_cor = estimates_h %>% filter(N_SAMP >=30 & is.na(N_SAMP)==F) # Used for variable selection

estimates_model = estimates_h %>% filter(is.na(N_SAMP)==F) # Used for model fitting

# Compute the correlation of the IV by sample type with each covariate 
correlation = matrix(nrow=length(variables), ncol=1, 
                     dimnames = list(NULL,IV))
for(j in 1:length(variables)) {
  correlation[j,1] = round(cor(x=estimates_cor[,IV],y=estimates_cor[,variables[j]], 
                               use="complete.obs"),2)
}

correlation = data.frame(VARIABLE=variables, correlation, SEL=0)
#print("Correlation")
#print(correlation)

# Model selection
# Start with the null model (intercept only)
null_model = lm(PREVALENCE ~ 1, data = estimates_cor[,c(IV,variables)])
# Full model with all predictors
full_model = lm(PREVALENCE ~ ., data = estimates_cor[,c(IV,variables)])

AIC.selection = step(null_model, scope = list(lower = null_model, upper = full_model), 
                     direction="forward", scale=0, k=3, trace = 0)
cat("\n Model Selection \n")
print(summary(AIC.selection))
final.variables = names(AIC.selection$coef)[-1]

# GVF standard errors
estimates_model = estimates_model %>% 
        mutate(GVF_SE = 
                 GVF.smooth(n=estimates_model$N_SAMP, 
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
temp = nlminb(start=median(estimates_model$GVF_SE^2), 
              obj=sigma.FH, lower=0.00001, upper=Inf, y=estimates_model$PREVALENCE, 
              psi=estimates_model$GVF_SE^2, X=X)
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
                        EST_TYPE, N_SAMP, CONDITION, SE, PREVALENCE_DIRECT, STATE))

cat("\n End of iteration \n\n")

}

sink()

# ZIP comparison

zip = estimates_weighted %>% group_by(CONDITION, ZIP) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP))

zip_excl2019 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) != "2019") %>%
  group_by(CONDITION, ZIP) %>% 
  summarize(MIN = min(PREVALENCE),
            MEDIAN = median(PREVALENCE),
            MAX = max(PREVALENCE),
            RATIO_MAX_MIN = MAX/MIN,
            N_SAMP = median(N_SAMP))

# State comparison

state = estimates_weighted %>% group_by(CONDITION, STATE, YEAR_MONTH) %>% 
  summarize(PREVALENCE_MODEL = mean(PREVALENCE))

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
  summarize(PREVALENCE_MODEL = mean(PREVALENCE))

# Export the summary files

sheets = list("ZIP" = zip,
              "ZIP2019" = zip_excl2019,
              "State" = state,
              "Htn Corr" = state_correlation_htn,
              "Htn-C Corr" = state_correlation_htnc,
              "National" = national
) 
write.xlsx(sheets, 'ZIP Model Output NEW.xlsx')

# Export the full data

estimates1 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2019"))
estimates2 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2020"))
estimates3 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2021"))
estimates4 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2022"))
estimates5 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2023"))
estimates6 = estimates_weighted %>% filter(substr(YEAR_MONTH,1,4) %in% c("2024"))

sheets = list("modeled_2019" = estimates1,
              "modeled_2020" = estimates2,
              "modeled_2021" = estimates3,
              "modeled_2022" = estimates4,
              "modeled_2023" = estimates5,
              "modeled_2024" = estimates6
) 
write.xlsx(sheets, 'ZIP_Estimates_All NEW.xlsx')

# Create the final data file

# Limit to month/state/indicator combinations with 15+ patients
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
estimates_final = rbind(estimates_weighted, estimates_crude) %>% 
  rename(NPATS = N_SAMP) %>%
  arrange(EST_TYPE, CONDITION, YEAR_MONTH, ZIP)

summary(estimates_final)
unique(estimates_final$YEAR_MONTH)
unique(estimates_final$ZIP)
unique(estimates_final$EST_TYPE)
unique(estimates_final$CONDITION)

# Export data

# Export the full data

estimates1 = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2019","2020"))
estimates2 = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2021","2022"))
estimates3 = estimates_final %>% filter(substr(YEAR_MONTH,1,4) %in% c("2023","2024"))

sheets = list("2019_2020" = estimates1,
              "2021_2022" = estimates2,
              "2023_2024" = estimates3
) 
write.xlsx(sheets, 'ZIP_Estimates_Modeled NEW.xlsx',  sep=",", rowNames=F)

