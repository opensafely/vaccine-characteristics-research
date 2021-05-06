# Program Information  ----------------------------------------------------

# Program:     04_plots_over_time.R
# Author:      Anna Schultze 
# Description: plot characteristics over time
# Input:       output/tempdata/study_population.csv
# Output:      output/plots/figure[].png
# Edits:      

# Housekeeping  -----------------------------------------------------------

# load packages 
library(tidyverse)
library(data.table)
library(janitor)
library(lubridate)
library(viridis)

# create output folders if they do not exist (if exist, will throw warning which is suppressed)

dir.create(file.path("./output/tables"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path("./output/plots"), showWarnings = FALSE, recursive = TRUE)

# Read in Data ------------------------------------------------------------
study_population <- fread("./output/tempdata/study_population.csv", data.table = FALSE, na.strings = "")

# Data Management ---------------------------------------------------------

study_population <- study_population %>% 
  # filter out data (missing only in dummy data)
  filter(!is.na(any_covid_vaccine_date)) %>% 
  filter(!is.na(vaccine_type)) %>% 
  # create a time variable (week since vaccination programme)
  mutate(weekdiff = difftime((dmy(any_covid_vaccine_date)),(dmy("08dec2020")), unit = "months"), 
         month = floor(monthdiff), 
         care_home_cat = case_when(
           care_home_type == "CareHome" ~ "Care Home", 
           care_home_type == "CareOrNursingHome" ~ "Care Home", 
           care_home_type == "NursingHome" ~ "Care Home", 
           care_home_type == "PrivateHome" ~ "Private Home", 
           TRUE ~ "Private Home"))

# Plot 1: Age over time ---------------------------------------------------
dodge <- position_dodge(width = 1)

age_plot <- ggplot(study_population, aes(fill = vaccine_type, x=as.factor(month), y=age)) + 
  geom_violin(trim=FALSE, position = dodge, alpha = 0.4) + 
  geom_boxplot(width=0.1, position = dodge, alpha = 0.6) + 
  scale_fill_viridis(discrete = "T", name = "") +
  theme_minimal() + 
  xlab("Week since start of vaccination programme") +
  ylab("Age at First Vaccination Dose (Years)") + 
  ylim(0,130) 
  
png(filename = "./output/plots/plot1.png")
age_plot
dev.off()

