#Peru Regional Export Trends (2005-2022)

# Data cleaning, transformation and type validation
library(tidyverse)  
library(lubridate)  
library(janitor)
library(readxl)

setwd("F:/data-analyst-portfolio/Peru Regional Export Trends (2005-2022)")
RAW_PATH <- "Peru Regional Export Trends (2005-2022) Raw data.xlsx"


# Read the raw data
raw <- read_excel(
  RAW_PATH,
  col_types = "text",
  sheet = "Mensuales"
) |>
  rename(month_label = 1)

glimpse(raw)


# Clean the column names into plain department names
data_named <- raw |>
  rename_with(~ str_trim(str_extract(., "(?<=-\\s)[^-]+$")), -month_label) |> #regex
  clean_names()


# Parse the month label into a proper date
spanish_month <- c(
  ene = 1, feb = 2, mar = 3, abr = 4, may = 5, jun = 6,
  jul = 7, ago = 8, sep = 9, oct = 10, nov = 11, dic = 12
)

data_dated <- data_named |>
  mutate(
    month_abbr = str_to_lower(str_sub(month_label, 1, 3)),
    year_2digit = as.integer(str_sub(month_label, 4, 5)),
    year = if_else(year_2digit >= 70, 1900L + year_2digit, 2000L + year_2digit),
    month = spanish_month[month_abbr],
    date = make_date(year, month, 1)
  ) |>
  select(-month_label, -month_abbr, -year_2digit, -year, -month) |>
  relocate(date)

glimpse(data_dated)


# Reshape to tidy (long) format and type the value column
exports_long <- data_dated |>
  pivot_longer(-date, names_to = "department", values_to = "export_value_raw") |>
  mutate(
    export_value = parse_double(export_value_raw, na = c("n.d.", "", "NA")),
    department = str_to_title(str_replace_all(department, "_", " "))
  ) |>
  select(date, department, export_value)

glimpse(exports_long)


# Validate: duplicates and missing data
# (date, department) pair must be unique: one value per region per month
duplicate_check <- exports_long |>
  count(date, department) |>
  filter(n > 1)

stopifnot(nrow(duplicate_check) == 0)

missing_summary <- exports_long |>
  group_by(department) |>
  summarise(
    n_months = n(),
    n_missing = sum(is.na(export_value)),
    pct_missing = round(100 * n_missing / n_months, 1)
  ) |>
  arrange(desc(pct_missing))

print(missing_summary)


# Build a wide matrix for clustering
exports_wide <- exports_long |>
  pivot_wider(names_from = date, values_from = export_value) |>
  arrange(department)

write_csv(exports_long,"Peru Regional Export Trends (2005-2022) Clean Data - Long.csv")
write_csv(exports_wide,"Peru Regional Export Trends (2005-2022) Clean Data - Wide.csv")

glimpse(exports_wide[, 1:15])

