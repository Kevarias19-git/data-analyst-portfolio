#' ---
#' title: "Peru Regional Export Trends (2005-2022) - Cleaning Data"
#' author: "Kevin Arias"
#' date: "`r Sys.Date()`"
#' output: html_document
#' ---

# ==============================================================================
# Data cleaning, transformation and type validation
# ==============================================================================

# 1. PACKAGES AND PATHS
library(tidyverse)
library(lubridate)
library(janitor)
library(readxl)
library(here)

# Input and output paths (relative to the project root, built with here())
RAW_PATH <- here("Peru Regional Export Trends (2005-2022)",
                 "Peru Regional Export Trends (2005-2022) Raw Data.xlsx")
OUT_PATH <- here("Peru Regional Export Trends (2005-2022)",
                 "Peru Regional Export Trends (2005-2022) Clean Data - Long.csv")


# 2. IMPORT THE RAW DATA
raw <- read_excel(
  RAW_PATH,
  col_types = "text",
  sheet = "Mensuales"
) |>
  rename(month_label = 1) # The first column holds the month label

glimpse(raw)


# 3. CLEAN THE COLUMN NAMES
# Regex keeps only the text after the last "-" (the region name)
data_named <- raw |>
  rename_with(~ str_trim(str_extract(., "(?<=-\\s)[^-]+$")), -month_label) |> #regex
  clean_names()

# Names must not be missing or duplicated
stopifnot(!anyNA(names(data_named)), !anyDuplicated(names(data_named)))


# 4. PARSE THE MONTH LABEL INTO A DATE
spanish_month <- c(
  ene = 1, feb = 2, mar = 3, abr = 4, may = 5, jun = 6,
  jul = 7, ago = 8, sep = 9, oct = 10, nov = 11, dic = 12
)

# Split the label into month and 2-digit year, then build the first day of the month
data_dated <- data_named |>
  mutate(
    month_abbr = str_to_lower(str_sub(month_label, 1, 3)),
    year_2digit = as.integer(str_sub(month_label, 4, 5)),
    year = 2000L + year_2digit,   # the data covers 2005-2022
    month = spanish_month[month_abbr],
    date = make_date(year, month, 1)
  ) |>
  select(-month_label, -month_abbr, -year_2digit, -year, -month) |>
  relocate(date)

glimpse(data_dated)


# 5. RESHAPE TO LONG FORMAT AND TYPE THE VALUES
# One row per date and department; export_value is converted to numeric
# Note: "department" also contains "Total" and "No Registrado", which are not
# real regions (Callao is a constitutional province, kept as a region)
exports_long <- data_dated |>
  pivot_longer(-date, names_to = "department", values_to = "export_value_raw") |>
  mutate(
    export_value = parse_double(export_value_raw, na = c("n.d.", "", "NA")),
    department = str_to_title(str_replace_all(department, "_", " "))
  ) |>
  select(date, department, export_value)

glimpse(exports_long)


# 6. VALIDATION (DUPLICATES, MISSING VALUES, ZEROS AND TOTAL)
# 6.1 Duplicates: each (date, department) pair must be unique
duplicate_check <- exports_long |>
  count(date, department) |>
  filter(n > 1)

stopifnot(nrow(duplicate_check) == 0)

# 6.2 Missing values by department
missing_summary <- exports_long |>
  group_by(department) |>
  summarise(
    n_months = n(),
    n_missing = sum(is.na(export_value)),
    pct_missing = round(100 * n_missing / n_months, 1)
  ) |>
  arrange(desc(pct_missing))

print(missing_summary, n = Inf)

# 6.3 Zero values by department
zero_summary <- exports_long |>
  filter(export_value == 0) |>
  count(department, name = "n_zero_months") |>
  arrange(desc(n_zero_months))

print(zero_summary, n = Inf)

# 6.4 Total check: the regions plus "No Registrado" should add up to "Total"
# Difference between the sum of all the series and the "Total" series, by month
total_check <- exports_long |>
  mutate(is_total = department == "Total") |>
  group_by(date, is_total) |>
  summarise(value = sum(export_value), .groups = "drop") |>
  pivot_wider(names_from = is_total, values_from = value, names_prefix = "total_") |>
  mutate(diff = abs(total_FALSE - total_TRUE))
max(total_check$diff)


# 7. SAVE THE CLEAN TABLE
write_csv(exports_long, OUT_PATH)

