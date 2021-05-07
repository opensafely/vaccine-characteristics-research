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
  mutate(month = month((dmy(any_covid_vaccine_date)), label = TRUE),
         care_home_cat = case_when(
           care_home_type == "CareHome" ~ "Care Home", 
           care_home_type == "CareOrNursingHome" ~ "Care Home", 
           care_home_type == "NursingHome" ~ "Care Home", 
           care_home_type == "PrivateHome" ~ "Private Home", 
           TRUE ~ "Private Home")) %>% 
  mutate(month = factor(month, levels = c("Dec", "Jan", "Feb", "Mar", "Apr", "May"))) 

# Plot 1: Age over time ---------------------------------------------------
age_plot <- ggplot(study_population, aes(age, fill = vaccine_type)) + 
  geom_histogram(binwidth = 5, alpha = 0.5, color = "gray80") + 
  scale_fill_viridis(discrete = "T", name = "") +
  scale_color_viridis() + 
  theme_minimal() + 
  xlab("Age") + 
  ylab("Number of People") +
  facet_wrap(month ~ ., 
             nrow = 6, 
             strip.position = c("bottom"))

png(filename = "./output/plots/plot1.png")
age_plot
dev.off()





