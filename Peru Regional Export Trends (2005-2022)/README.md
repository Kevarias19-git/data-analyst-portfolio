Peru Regional Export Trends (2005-2022): Data Cleaning, Exploratory Analysis and Machine Learning Using RStudio
================
By Kevin Arias


## Project Overview

This exploratory analysis is a personal portfolio project. I selected this topic due to my interest in international trade, regional economics and the Peruvian economy. In this project, I use *RStudio* for the entire process: data cleaning, exploratory analysis and machine learning, with the `tidyverse` for wrangling and plotting and the `tidymodels` framework for modeling.

The dataset comes from the *Banco Central de Reserva del Perú* (BCRP) statistical portal, in the section of monthly series of exports and imports. The series used is **"Exportaciones por Departamento (Valores FOB en millones US$)"**, which contains **monthly export values in millions of US$ (FOB)** for **25 regions** (24 departments plus Callao) from **January 2005 to December 2022** (216 months), plus the national **"Total"** and a **"No registrado"** (not registered) category.

The main **objective** is to identify patterns, groups of similar regions and predictable behavior in Peru's regional exports, using both unsupervised (PCA and clustering) and supervised (classification) techniques.

For readability, I have divided this project into **5 phases** as follows:

- **Phase 1:** Cleaning and preparing data.

- **Phase 2:** Loading and understanding the clean data.

- **Phase 3:** Exploratory data analysis (EDA).

- **Phase 4:** Machine learning: feature engineering, PCA, clustering and classification.

- **Phase 5:** Sharing insights from the analysis.


&nbsp;

## Phase 1: Cleaning and preparing data

In this phase I understand the raw Excel file and transform it into a clean long-format table. The compiled report is [Peru-Regional-Export-Trends (2005-2022) Cleaning Data.html](https://github.com/Kevarias19-git/data-analyst-portfolio/blob/main/Peru%20Regional%20Export%20Trends%20(2005-2022)/Peru-Regional-Export-Trends--2005-2022--Cleaning-Data.html).

### 1.1 Loading packages and defining paths

I will import the following libraries:

- **tidyverse** for wrangling and plotting (`dplyr`, `tidyr`, `readr`, `stringr`, `ggplot2`, etc.).
- **lubridate** for building and handling dates.
- **janitor** for cleaning column names with `clean_names()`.
- **readxl** for reading the Excel workbook.
- **here** for building file paths relative to the project folder.

```r
library(tidyverse)
library(lubridate)
library(janitor)
library(readxl)
library(here)
````

Then I define the input path (the raw Excel file) and the output path (the clean CSV file).

```r
# Input and output paths (relative to the project root, built with here())
RAW_PATH <- here("Peru Regional Export Trends (2005-2022)",
                 "Peru Regional Export Trends (2005-2022) Raw Data.xlsx")
OUT_PATH <- here("Peru Regional Export Trends (2005-2022)",
                 "Peru Regional Export Trends (2005-2022) Clean Data - Long.csv")
```

&nbsp;

### 1.2 Importing the raw data

The workbook has two sheets: `Metadatos` (metadata of each series) and `Mensuales` (the monthly values). I read `Mensuales` with `read_excel()`, importing **every column as text** (`col_types = "text"`) so that I control the data types myself later, and I rename the first (unnamed) column to `month_label`.

```r
raw <- read_excel(
  RAW_PATH,
  col_types = "text",
  sheet = "Mensuales"
) |>
  rename(month_label = 1) # The first column holds the month label
```

```
>## New names:
>## • `` -> `...1`
```

Now I review the structure of the raw data with `glimpse()`.

```r
glimpse(raw)
```

```
>## Rows: 216
>## Columns: 28
>## $ month_label                                                                    <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Amazonas`      <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Ancash`        <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Apurimac`      <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Arequipa`      <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Ayacucho`      <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Cajamarca`     <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Callao`        <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Cusco`         <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Huancavelica`  <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Huánuco`       <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Ica`           <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Junín`         <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - La Libertad`   <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Lambayeque`    <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Lima`          <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Loreto`        <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Madre de Dios` <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Moquegua`      <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Pasco`         <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Piura`         <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Puno`          <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - San Martín`    <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Tacna`         <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Tumbes`        <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Ucayali`       <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - No registrado` <chr> …
>## $ `Exportaciones por Departamento (Valores FOB en millones US$) - Total`         <chr> …
```

Quick observation:

- The raw data has **216 rows** (one per month) and **28 columns**: the month label plus **27 series**.
- The 27 series are the **24 departments, Callao, "No registrado" and "Total"**.
- Every column is `chr` because of `col_types = "text"`.
- Each column name repeats a long prefix ("Exportaciones por Departamento (Valores FOB en millones US$) - "), so the names must be cleaned.
- Some names have accents (Huánuco, Junín, San Martín)

&nbsp;

### 1.3 Cleaning the column names

I keep only the text after the last "-" of each name (the region name) with a regular expression, and then use `clean_names()` to convert the names to snake_case. `clean_names()` also removes the accents. A check ensures that no name is missing or duplicated.

```r
# Regex keeps only the text after the last "-" (the region name)
data_named <- raw |>
  rename_with(~ str_trim(str_extract(., "(?<=-\\s)[^-]+$")), -month_label) |> #regex
  clean_names()
# Names must not be missing or duplicated
stopifnot(!anyNA(names(data_named)), !anyDuplicated(names(data_named)))
```

&nbsp;

### 1.4 Converting the month label into a date

The month labels use **Spanish abbreviations and a 2-digit year** (e.g., "Ene05" is January 2005). I map each abbreviation to its month number, build the year as 2000 plus the 2-digit year (the data covers 2005-2022) and create a `date` column with the first day of each month using `make_date()`.

```r
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
```

```r
glimpse(data_dated)
```

```
>## Rows: 216
>## Columns: 28
>## $ date          <date> 2005-01-01, 2005-02-01, 2005-03-01, 2005-04-01, 2005-05…
>## $ amazonas      <chr> "0.17747598000000001", "0.14609612999999999", "0.1188464…
>## $ ancash        <chr> "188.67116525", "151.56680567000001", "198.2916658499999…
>## $ apurimac      <chr> "4.6213000000000001E-3", "0", "4.5003654400000004", "3.4…
>## $ arequipa      <chr> "27.92751664", "31.441480909999999", "56.98445005", "55.…
>## $ ayacucho      <chr> "0.23633488", "9.5425910000000003E-2", "0.40723288000000…
>## $ cajamarca     <chr> "83.760161960000005", "134.97155283000001", "121.1802656…
>## $ callao        <chr> "94.459618709999901", "74.012058489999902", "89.04394454…
>## $ cusco         <chr> "28.979170140000001", "7.4287640100000001", "45.41003553…
>## $ huancavelica  <chr> "0", "3.5282979999999999E-2", "0.71745338000000003", "0.…
>## $ huanuco       <chr> "8.9615280000000005E-2", "0.27758623999999998", "1.75166…
>## $ ica           <chr> "69.489297269999895", "54.805289850000001", "77.77187809…
>## $ junin         <chr> "52.628680080000002", "60.487884739999998", "55.97584630…
>## $ la_libertad   <chr> "35.696191159999898", "19.470245510000002", "25.13556579…
>## $ lambayeque    <chr> "13.31461987", "7.4155846099999998", "11.926019670000001…
>## $ lima          <chr> "327.89882313999999", "342.79129994000198", "357.7328834…
>## $ loreto        <chr> "4.6842618900000002", "5.86212993", "2.91966116", "6.976…
>## $ madre_de_dios <chr> "0.43190005999999997", "0.89065970999999999", "0.8369327…
>## $ moquegua      <chr> "170.00505146", "100.39690865", "108.51275557", "171.166…
>## $ pasco         <chr> "11.43615445", "18.01980403", "53.528015349999997", "32.…
>## $ piura         <chr> "63.699173610000202", "68.870471540000295", "61.39738477…
>## $ puno          <chr> "4.4378469799999998", "5.7132502900000004", "7.045924949…
>## $ san_martin    <chr> "3.9454286500000002", "0.85441984999999998", "0.23765933…
>## $ tacna         <chr> "72.214435199999997", "39.728952640000003", "53.41822191…
>## $ tumbes        <chr> "3.9639107400000002", "5.7600312300000001", "5.268650430…
>## $ ucayali       <chr> "1.20100574", "1.6669341900000001", "1.9067392400000001"…
>## $ no_registrado <chr> "4.7015554996505697", "4.2877654439944299", "5.473865833…
>## $ total         <chr> "1264.0540159396501", "1136.9966853240001", "1347.493925…
```

- The new `date` column has the type `<date>`, from 2005-01-01 to 2022-12-01.
- The values of the 27 series are still `chr`. Some appear in scientific notation, so they must be converted to numbers.

&nbsp;

### 1.5 Reshaping to long format and typing the values

I reshape the data to **tidy (long) format** with `pivot_longer()`: one row per date and department. The values are converted to numeric with `parse_double()` (treating "n.d.", empty cells and "NA" as missing values), and the department names are converted to title case.

Note that `department` also contains **"Total"** and **"No Registrado"**, which are not real regions, and that **Callao** is a constitutional province that I keep as a region.

```r
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
```

```r
glimpse(exports_long)
```

```
>## Rows: 5,832
>## Columns: 3
>## $ date         <date> 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-…
>## $ department   <chr> "Amazonas", "Ancash", "Apurimac", "Arequipa", "Ayacucho",…
>## $ export_value <dbl> 0.17747598, 188.67116525, 0.00462130, 27.92751664, 0.2363…
```

- The clean table has **5,832 rows and 3 columns** (27 series x 216 months).

&nbsp;

### 1.6 Validating duplicates, missing values, zeros and the total

**Duplicates.** Each (`date`, `department`) pair must be unique. The check stops the script if a duplicate exists, and it passed.

```r
# 6.1 Duplicates: each (date, department) pair must be unique
duplicate_check <- exports_long |>
  count(date, department) |>
  filter(n > 1)
stopifnot(nrow(duplicate_check) == 0)
```

**Missing values.** I count the missing values by department.

```r
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
```

```
>## # A tibble: 27 × 4
>##    department    n_months n_missing pct_missing
>##    <chr>            <int>     <int>       <dbl>
>##  1 Amazonas           216         0           0
>##  2 Ancash             216         0           0
>##  3 Apurimac           216         0           0
>##  4 Arequipa           216         0           0
>##  5 Ayacucho           216         0           0
>##  6 Cajamarca          216         0           0
>##  7 Callao             216         0           0
>##  8 Cusco              216         0           0
>##  9 Huancavelica       216         0           0
>## 10 Huanuco            216         0           0
>## 11 Ica                216         0           0
>## 12 Junin              216         0           0
>## 13 La Libertad        216         0           0
>## 14 Lambayeque         216         0           0
>## 15 Lima               216         0           0
>## 16 Loreto             216         0           0
>## 17 Madre De Dios      216         0           0
>## 18 Moquegua           216         0           0
>## 19 No Registrado      216         0           0
>## 20 Pasco              216         0           0
>## 21 Piura              216         0           0
>## 22 Puno               216         0           0
>## 23 San Martin         216         0           0
>## 24 Tacna              216         0           0
>## 25 Total              216         0           0
>## 26 Tumbes             216         0           0
>## 27 Ucayali            216         0           0
```

- **There are no missing values** in any of the 27 series.

**Zero values.** I count the months with an export value of exactly 0.

```r
# 6.3 Zero values by department
zero_summary <- exports_long |>
  filter(export_value == 0) |>
  count(department, name = "n_zero_months") |>
  arrange(desc(n_zero_months))
print(zero_summary, n = Inf)
```

```
>## # A tibble: 5 × 2
>##   department    n_zero_months
>##   <chr>                 <int>
>## 1 Apurimac                 16
>## 2 No Registrado            10
>## 3 Amazonas                  5
>## 4 Huancavelica              3
>## 5 Madre De Dios             1
```

- There are **35 zero values**: Apurimac (16), "No Registrado" (10), Amazonas (5), Huancavelica (3) and Madre de Dios (1). The BCRP reports values at full precision (even exports of a few US$ appear as non-zero), so these zeros are true zeros, meaning no exports recorded that month, not rounding. I keep them as reported. All 16 zeros of Apurimac fall between 2005 and 2011, before the Las Bambas mine started operating.

**Total check.** The 25 regions plus "No Registrado" should add up to the national "Total". I calculate the absolute difference by month.

```r
# 6.4 Total check: the regions plus "No Registrado" should add up to "Total"
# Difference between the sum of all the series and the "Total" series, by month
total_check <- exports_long |>
  mutate(is_total = department == "Total") |>
  group_by(date, is_total) |>
  summarise(value = sum(export_value), .groups = "drop") |>
  pivot_wider(names_from = is_total, values_from = value, names_prefix = "total_") |>
  mutate(diff = abs(total_FALSE - total_TRUE))
max(total_check$diff)
```

```
>## [1] 9.094947e-12
```

- The maximum difference is about **9.094947e-12**, which is practically zero. The regions plus "No Registrado" add up to the national total in every month, so the data is **internally consistent**.

&nbsp;

### 1.7 Saving the clean table

Finally, I save the clean long-format table as a CSV file, which is the input of the machine learning script.

```r
write_csv(exports_long, OUT_PATH)
```

&nbsp;

## Phase 2: Loading and understanding the clean data

The following phases use the machine learning script [Peru-Regional-Export-Trends (2005-2022) ML-Scripts](https://github.com/Kevarias19-git/data-analyst-portfolio/blob/main/Peru%20Regional%20Export%20Trends%20(2005-2022)/Peru-Regional-Export-Trends--2005-2022--ML-Scripts.html).

### 2.1 Loading packages

I will import the following libraries:

- **tidyverse** and **lubridate** for wrangling, dates and plotting with `ggplot2`.
- **tidymodels** for preprocessing recipes, model specifications, workflows and evaluation metrics.
- **factoextra** for visualizing PCA and clustering results.
- **skimr** for a quick summary of the data.
- **here** for building file paths relative to the project folder.

I also set a seed (`set.seed(123)`) so that the results are reproducible.

```r
suppressPackageStartupMessages({
library(tidyverse)
library(lubridate)
library(tidymodels)
library(factoextra) # Visualize PCA and clustering
library(skimr)
library(here)
})
suppressMessages({
tidymodels_prefer()
conflicted::conflicts_prefer(dplyr::lag)
})
set.seed(123)
```

&nbsp;

### 2.2 Importing the clean data

The clean long-format table produced by the cleaning script is imported with `read_csv()`, defining the column types explicitly.

```r
# Load the clean long-format table produced by the cleaning script
df_long <- read_csv(
  here("Peru Regional Export Trends (2005-2022)","Peru Regional Export Trends (2005-2022) Clean Data - Long.csv"),
  col_types = cols(date = col_date(), department = col_character(), export_value = col_double())
)
```

&nbsp;

### 2.3 Reviewing the data

Two data frames are created from the original table:

- `df_total` keeps the national **"Total"** series, which is used later to compute each region's share of national exports.
- `df_model` removes **"Total"** and **"No Registrado"** so that only real regions remain.

I then use `glimpse()` and `skim()` to understand the structure of `df_model`.

```r
# Keep the national total separately to compute regional shares
df_total <- df_long %>%
  filter(department == "Total")
# Remove "Total" and "No Registrado" to keep only real regions
df_model <- df_long %>%
  filter(!department %in% c("Total", "No Registrado"))
glimpse(df_model)
```

```
>## Rows: 5,400
>## Columns: 3
>## $ date         <date> 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-…
>## $ department   <chr> "Amazonas", "Ancash", "Apurimac", "Arequipa", "Ayacucho",…
>## $ export_value <dbl> 0.17747598, 188.67116525, 0.00462130, 27.92751664, 0.2363…
```

```r
skim(df_model)
```

```
>## Data summary Name 	df_model
>## Number of rows 	5400
>## Number of columns 	3
>## _______________________ 	
>## Column type frequency: 	
>## character 	1
>## Date 	1
>## numeric 	1
>## ________________________ 	
>## Group variables 	None
>## 
>## Variable type: character
>## skim_variable 	n_missing 	complete_rate 	min 	max 	empty 	n_unique 	whitespace
>## department 	0 	1 	3 	13 	0 	25 	0
>## 
>## Variable type: Date
>## skim_variable 	n_missing 	complete_rate 	min 	max 	median 	n_unique
>## date 	0 	1 	2005-01-01 	2022-12-01 	2013-12-16 	216
>## 
>## Variable type: numeric
>## skim_variable 	n_missing 	complete_rate 	mean 	sd 	p0 	p25 	p50 	p75 	p100 	hist
>## export_value 	0 	1 	133.11 	194.14 	0 	6.83 	48.53 	198.76 	1696.54 	▇▁▁▁▁
```

Quick observation:

- `df_model` has **5,400 rows and 3 columns** (25 regions x 216 months).
- There are **no missing values** in any column (complete rate = 1).
- Dates range from **2005-01-01 to 2022-12-01**, with 216 unique months.
- The mean monthly export value is **133.11** with a standard deviation of **194.14**. The median (**48.53**) is far below the mean and the maximum is **1,696.54**, so the distribution is **strongly right-skewed**. This is expected because a few regions export much more than the rest.
- The minimum value is **0** because of the real zero values found in Phase 1 (Apurimac, Amazonas, Huancavelica and Madre de Dios).

&nbsp;

## Phase 3: Exploratory data analysis (EDA)

### 3.1 Export evolution by region

I plot one line chart per region (`facet_wrap` with a free y-axis) to see each region's trajectory over time.

```r
# 2.1 Plot one line chart per region
plot_lines <- df_model %>%
  ggplot(aes(x = date, y = export_value)) +
  geom_line() +
  facet_wrap(~ department, scales = "free_y") +
  theme_minimal() +
  labs(title = "Export Evolution by Region (2005-2022)", x = "Date", y = "Value")
plot_lines
```

![Plot Evolution by Region](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Export%20Evolution%20by%20Region%20%282005-2022%29.png)

Here are some insights we can draw from the charts:

- Most regions show an **upward trend** over the period, for example Arequipa, Ica, La Libertad, Lambayeque, Cusco and Puno.
- **Apurimac** is almost flat until about **2015-2016** and then jumps sharply. This coincides with the start of production at the **Las Bambas** copper mine, whose first copper concentrate shipment left for China in January 2016 [source](https://www.e-mj.com/leading-developments/las-bambas-produces-ships-first-copper-concentrate-las-bambas).
- **Ayacucho** shows a clear step up around **2020-2021**. Its exports are almost entirely **gold** (about US$754M of US$813M in 2021, up from US$674M of US$722M in 2020), so the increase mainly reflects gold exports [source](https://recursos.exportemos.pe//infografia-region-ayacucho-2021.pdf).
- **Huancavelica, Huanuco and Pasco** peak in the early and mid 2010s and then decline.
- Several regions show a **sharp drop around 2020** (COVID-19), for example Lima, Callao, Arequipa, Ica and Ancash.
- Because each panel uses its own scale, the charts compare **shapes**, not **sizes**.

&nbsp;

### 3.2 Monthly heatmap for one region (Arequipa)

To look for seasonality, I build a month vs. year heatmap for **Arequipa**.

```r
# 2.2 Plot a month vs year heatmap for one region (e.g., Arequipa)
plot_heatmap_Arequipa <- df_model %>%
  filter(department == "Arequipa") %>%
  mutate(year = year(date),month = factor(month(date), levels = 1:12, labels = month.abb)) %>%
  ggplot(aes(x = month, y = factor(year), fill = export_value)) +
  geom_tile(color = "white") +
  scale_fill_viridis_c() +
  theme_minimal() +
  labs(title = "Monthly Heatmap - Arequipa", x = "Month", y = "Year")
plot_heatmap_Arequipa
```

![Heatmap Arequipa](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Monthly%20Heatmap%20-%20Arequipa.png)

- The color changes much more from **top to bottom (years)** than from **left to right (months)**, so the **long-term growth** dominates over any seasonal pattern.
- A clear dip appears in **April 2020**, which matches the COVID-19 lockdown.
- The highest values appear in **2021 and 2022**.

&nbsp;

### 3.3 Average share of each region in national exports

I join each region with the national total by date, compute its monthly share and then average it over the whole period.

```r
# 2.3 Compute the average share of each region in national exports
df_share <- df_model %>%
  left_join(df_total %>% select(date, total_value = export_value), by = "date") %>%
  mutate(share = export_value / total_value) %>%
  group_by(department) %>%
  summarise(avg_share = mean(share, na.rm = TRUE), .groups = "drop")
print(df_share, n=25)
```

```
>## # A tibble: 25 × 2
>##    department    avg_share
>##    <chr>             <dbl>
>##  1 Amazonas       0.000493
>##  2 Ancash         0.103
>##  3 Apurimac       0.0190
>##  4 Arequipa       0.0854
>##  5 Ayacucho       0.00578
>##  6 Cajamarca      0.0616
>##  7 Callao         0.0821
>##  8 Cusco          0.0263
>##  9 Huancavelica   0.00214
>## 10 Huanuco        0.00141
>## 11 Ica            0.0868
>## 12 Junin          0.0278
>## 13 La Libertad    0.0615
>## 14 Lambayeque     0.0103
>## 15 Lima           0.242
>## 16 Loreto         0.00185
>## 17 Madre De Dios  0.00163
>## 18 Moquegua       0.0614
>## 19 Pasco          0.0185
>## 20 Piura          0.0551
>## 21 Puno           0.0194
>## 22 San Martin     0.00272
>## 23 Tacna          0.0120
>## 24 Tumbes         0.00313
>## 25 Ucayali        0.00115
```

```r
plot_share <- df_share %>%
  ggplot(aes(x = reorder(department, avg_share), y = avg_share)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() +
  labs(title = "Average Share of National Exports by Region", x = NULL, y = "Share")
plot_share
```

![Average Exports by Region](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Average%20Share%20of%20National%20Exports%20by%20Region.png)

- **Lima** alone represents about **24%** of national exports, followed by Ancash (10.3%), Ica (8.7%), Arequipa (8.5%) and Callao (8.2%).
- The **top 5 regions** together account for roughly **60%** of exports.
- Nine regions have a share **below 1%**: Amazonas, Ayacucho, Huancavelica, Huanuco, Loreto, Madre de Dios, San Martin, Tumbes and Ucayali.
- The 25 shares add up to about **99.3%**. The remainder corresponds to **"No Registrado"**, which is consistent with how the data was filtered.

&nbsp;

## Phase 4: Machine learning

### 4.1 Feature engineering (one row per region)

To describe each region's behavior with a few numbers, I create the following variables:

| Variable | Description |
|---|---|
| `mean_export` | Average monthly export value (size) |
| `sd_export` | Standard deviation of monthly exports |
| `cv` | Coefficient of variation (`sd / mean`), relative volatility |
| `slope_rel` | Linear trend slope divided by the mean |
| `r2_trend` | R-squared of the linear trend (strength of the trend) |
| `cagr` | Compound annual growth rate between 2005 and 2022 |
| `covid_drop` | Lowest monthly value of 2020 divided by the 2019 monthly mean (lower = bigger COVID-19 impact) |

These descriptive features use the **full period** and are used **only for PCA and clustering**, not for the classifier (section 4.5).

```r
# 3.1 Descriptive features using the full period (used only for PCA/clustering, not for the classifier)
features_raw <- df_model %>%
  arrange(department, date) %>%
  group_by(department) %>%
  mutate(t = row_number()) %>%                 # Create a time index for the linear trend
  summarise(
    mean_export = mean(export_value, na.rm = TRUE),
    sd_export   = sd(export_value, na.rm = TRUE),
    cv          = sd_export / mean_export,     # Coefficient of variation
    slope       = coef(lm(export_value ~ t))[2],             # lm() drops NA rows automatically
    r2_trend    = summary(lm(export_value ~ t))$r.squared,   # Strength of the linear trend
    cagr        = (sum(export_value[year(date) == 2022], na.rm = TRUE) /
                     sum(export_value[year(date) == 2005], na.rm = TRUE))^(1 / 17) - 1,   # Compound annual growth rate
    covid_drop  = suppressWarnings(min(export_value[year(date) == 2020], na.rm = TRUE)) /
      mean(export_value[year(date) == 2019], na.rm = TRUE),                # COVID-19 impact
    .groups = "drop"
  ) %>%
  mutate(slope_rel = slope / mean_export) %>%  # Express the slope relative to the mean
  select(-slope) %>%
  filter(if_all(where(is.numeric), is.finite)) # Remove regions with undefined values
print(features_raw, n=25)
```

```
>## # A tibble: 25 × 8
>##    department mean_export sd_export    cv r2_trend     cagr covid_drop slope_rel
>##    <chr>            <dbl>     <dbl> <dbl>    <dbl>    <dbl>      <dbl>     <dbl>
>##  1 Amazonas          1.91      2.23 1.17    0.322   0.167       0.151   0.0106
>##  2 Ancash          334.      113.   0.337   0.155   0.0517      0.139   0.00212
>##  3 Apurimac         77.6     111.   1.44    0.495   0.277       0.0143  0.0161
>##  4 Arequipa        299.      136.   0.454   0.637   0.146       0.348   0.00580
>##  5 Ayacucho         22.6      22.3  0.989   0.698   0.368       0.451   0.0132
>##  6 Cajamarca       195.       75.2  0.385   0.0243  0.0119      0.258   0.000960
>##  7 Callao          280.      130.   0.465   0.379   0.0772      0.193   0.00458
>##  8 Cusco            94.8      68.0  0.718   0.615   0.113       0.0296  0.00900
>##  9 Huancavel…        6.97      7.77 1.11    0.0214  0.270       0.472  -0.00260
>## 10 Huanuco           4.25      4.85 1.14    0.0197 -0.0608      0.103  -0.00257
>## 11 Ica             300.      142.   0.475   0.434   0.108       0.434   0.00501
>## 12 Junin            84.9      40.3  0.475   0.0390  0.0495      0.457   0.00150
>## 13 La Libert…      210.       86.0  0.409   0.627   0.124       0.633   0.00519
>## 14 Lambayeque       36.6      24.2  0.662   0.584   0.114       0.680   0.00809
>## 15 Lima            802.      258.   0.322   0.380   0.0737      0.490   0.00318
>## 16 Loreto            5.84      7.57 1.30    0.0263  0.0780      0.0406  0.00337
>## 17 Madre De …        5.84      5.10 0.873   0.307   0.224       0.653   0.00774
>## 18 Moquegua        194.       76.0  0.393   0.0458  0.0455      0.395   0.00134
>## 19 Pasco            56.2      39.0  0.694   0.105   0.0193      0.435  -0.00361
>## 20 Piura           186.       79.8  0.428   0.403   0.0899      0.410   0.00435
>## 21 Puno             72.6      58.1  0.800   0.711   0.196       0.315   0.0108
>## 22 San Martin        9.24      6.50 0.704   0.0750  0.0918      0.655   0.00308
>## 23 Tacna            34.7      18.8  0.542   0.0133 -0.00389     0.861  -0.000998
>## 24 Tumbes           10.1       4.31 0.425   0.159   0.0560      0.256   0.00271
>## 25 Ucayali           3.82      3.10 0.811   0.122   0.104       0.193   0.00453
```

I then apply a **log10(x + 1)** transformation to `mean_export` and `sd_export`, because their scales are very skewed (from about 4 to 800).

```r
# 3.2 Apply a log10 transformation to the variables with a skewed scale
features_log <- features_raw %>%
  mutate(
    mean_export = log10(mean_export + 1),
    sd_export   = log10(sd_export + 1)
  )
print(features_log, n=25)
```

```
>## # A tibble: 25 × 8
>##    department mean_export sd_export    cv r2_trend     cagr covid_drop slope_rel
>##    <chr>            <dbl>     <dbl> <dbl>    <dbl>    <dbl>      <dbl>     <dbl>
>##  1 Amazonas         0.464     0.510 1.17    0.322   0.167       0.151   0.0106
>##  2 Ancash           2.53      2.06  0.337   0.155   0.0517      0.139   0.00212
>##  3 Apurimac         1.90      2.05  1.44    0.495   0.277       0.0143  0.0161
>##  4 Arequipa         2.48      2.14  0.454   0.637   0.146       0.348   0.00580
>##  5 Ayacucho         1.37      1.37  0.989   0.698   0.368       0.451   0.0132
>##  6 Cajamarca        2.29      1.88  0.385   0.0243  0.0119      0.258   0.000960
>##  7 Callao           2.45      2.12  0.465   0.379   0.0772      0.193   0.00458
>##  8 Cusco            1.98      1.84  0.718   0.615   0.113       0.0296  0.00900
>##  9 Huancavel…       0.902     0.943 1.11    0.0214  0.270       0.472  -0.00260
>## 10 Huanuco          0.720     0.767 1.14    0.0197 -0.0608      0.103  -0.00257
>## 11 Ica              2.48      2.16  0.475   0.434   0.108       0.434   0.00501
>## 12 Junin            1.93      1.62  0.475   0.0390  0.0495      0.457   0.00150
>## 13 La Libert…       2.32      1.94  0.409   0.627   0.124       0.633   0.00519
>## 14 Lambayeque       1.57      1.40  0.662   0.584   0.114       0.680   0.00809
>## 15 Lima             2.90      2.41  0.322   0.380   0.0737      0.490   0.00318
>## 16 Loreto           0.835     0.933 1.30    0.0263  0.0780      0.0406  0.00337
>## 17 Madre De …       0.835     0.785 0.873   0.307   0.224       0.653   0.00774
>## 18 Moquegua         2.29      1.89  0.393   0.0458  0.0455      0.395   0.00134
>## 19 Pasco            1.76      1.60  0.694   0.105   0.0193      0.435  -0.00361
>## 20 Piura            2.27      1.91  0.428   0.403   0.0899      0.410   0.00435
>## 21 Puno             1.87      1.77  0.800   0.711   0.196       0.315   0.0108
>## 22 San Martin       1.01      0.875 0.704   0.0750  0.0918      0.655   0.00308
>## 23 Tacna            1.55      1.30  0.542   0.0133 -0.00389     0.861  -0.000998
>## 24 Tumbes           1.05      0.725 0.425   0.159   0.0560      0.256   0.00271
>## 25 Ucayali          0.683     0.613 0.811   0.122   0.104       0.193   0.00453
```

&nbsp;

### 4.2 Checking collinearity and standardizing

I compute the correlation matrix to check collinearity among the variables.

```r
# 3.3 Check collinearity among variables
cor_matrix <- features_log %>%
  select(-department) %>%
  cor()
cor_matrix
```

```
>##              mean_export   sd_export          cv     r2_trend        cagr
>## mean_export  1.000000000  0.97764743 -0.69664641  0.346833211 -0.16698617
>## sd_export    0.977647430  1.00000000 -0.53599110  0.426565440 -0.04852328
>## cv          -0.696646407 -0.53599110  1.00000000 -0.020932763  0.47082196
>## r2_trend     0.346833211  0.42656544 -0.02093276  1.000000000  0.56605748
>## cagr        -0.166986171 -0.04852328  0.47082196  0.566057479  1.00000000
>## covid_drop   0.064237970 -0.01402284 -0.37162454  0.004616824  0.02076543
>## slope_rel    0.006979914  0.11895229  0.34431519  0.765597893  0.70917497
>##               covid_drop    slope_rel
>## mean_export  0.064237970  0.006979914
>## sd_export   -0.014022838  0.118952291
>## cv          -0.371624541  0.344315195
>## r2_trend     0.004616824  0.765597893
>## cagr         0.020765430  0.709174969
>## covid_drop   1.000000000 -0.221477724
>## slope_rel   -0.221477724  1.000000000
```

`mean_export` and `sd_export` have a correlation of **0.98**, so I remove highly correlated variables (|r| > 0.9) with `step_corr()`. `mean_export` is removed and **6 variables** remain: `sd_export`, `cv`, `r2_trend`, `cagr`, `covid_drop` and `slope_rel`.

```r
# 3.4 Discard highly correlated variables (|r| > 0.9)
corr_recipe <- recipe(~ ., data = features_log) %>%
  update_role(department, new_role = "id") %>%
  step_corr(all_numeric_predictors(), threshold = 0.9) %>%
  prep()
features_selected <- bake(corr_recipe, new_data = NULL)
```

These are standardized with `scale()` because the variables have very different scales.

```r
# 3.5 Standardize variables (crucial because of different scales)
features_scaled <- features_selected %>%
  column_to_rownames("department") %>%
  scale()
features_scaled
```

```
>##                sd_export           cv    r2_trend        cagr  covid_drop
>## Amazonas      -1.7178215  1.427161096  0.10527236  0.57176528 -0.93397141
>## Ancash         0.9543909 -1.112291729 -0.56633550 -0.62075971 -0.98859409
>## Apurimac       0.9449724  2.248051894  0.79743251  1.71724331 -1.53733258
>## Arequipa       1.0936832 -0.753741725  1.37014986  0.35863997 -0.06564523
>## Ayacucho      -0.2353765  0.882579274  1.61280073  2.65560018  0.39046866
>## Cajamarca      0.6535781 -0.967192224 -1.08964046 -1.03296812 -0.46252817
>## Callao         1.0601616 -0.721635135  0.33271844 -0.35726767 -0.74968372
>## Cusco          0.5794038  0.052278896  1.27948866  0.01191888 -1.46986361
>## Huancavelica  -0.9691625  1.264452340 -1.10160561  1.63815912  0.48326749
>## Huanuco       -1.2723960  1.353406137 -1.10830888 -1.78580561 -1.14777651
>## Ica            1.1283735 -0.689628779  0.55542414 -0.03898595  0.31567352
>## Junin          0.1949009 -0.690188204 -1.03099269 -0.64359247  0.41858594
>## La Libertad    0.7528334 -0.891221062  1.32729208  0.12580618  1.19351865
>## Lambayeque    -0.1768846 -0.119498138  1.15624663  0.02551250  1.39937029
>## Lima           1.5722193 -1.159083188  0.33931940 -0.39303228  0.56265940
>## Loreto        -0.9861707  1.821434130 -1.08158046 -0.34833568 -1.42111939
>## Madre De Dios -1.2415851  0.527053870  0.04405218  1.16842706  1.28268294
>## Moquegua       0.6614019 -0.942569801 -1.00363711 -0.68544473  0.14151700
>## Pasco          0.1703755 -0.019094230 -0.76442636 -0.95623767  0.32076375
>## Piura          0.6974159 -0.834032432  0.42873045 -0.22509556  0.20751297
>## Puno           0.4629525  0.303793203  1.66761774  0.87693512 -0.21189352
>## San Martin    -1.0861955  0.009741765 -0.88620948 -0.20577261  1.29276749
>## Tacna         -0.3565181 -0.485609366 -1.13411403 -1.19664705  2.19955734
>## Tumbes        -1.3448432 -0.842260697 -0.55047400 -0.57621286 -0.46945662
>## Ucayali       -1.5397090  0.338094104 -0.69922060 -0.08384963 -0.75048058
>##                  slope_rel
>## Amazonas       1.235764065
>## Ancash        -0.493616377
>## Apurimac       2.368830090
>## Arequipa       0.257616050
>## Ayacucho       1.770786208
>## Cajamarca     -0.730819957
>## Callao         0.007410334
>## Cusco          0.910637678
>## Huancavelica  -1.458195327
>## Huanuco       -1.450302595
>## Ica            0.096007766
>## Junin         -0.620554285
>## La Libertad    0.131545638
>## Lambayeque     0.724102315
>## Lima          -0.278416748
>## Loreto        -0.239995625
>## Madre De Dios  0.651989087
>## Moquegua      -0.652445998
>## Pasco         -1.662766333
>## Piura         -0.039634371
>## Puno           1.276235322
>## San Martin    -0.297244764
>## Tacna         -1.130477041
>## Tumbes        -0.373355959
>## Ucayali       -0.003099175
>## attr(,"scaled:center")
>##   sd_export          cv    r2_trend        cagr  covid_drop   slope_rel
>## 1.503628471 0.700602349 0.295875087 0.111659551 0.362564978 0.004541143
>## attr(,"scaled:scale")
>##   sd_export          cv    r2_trend        cagr  covid_drop   slope_rel
>## 0.578674862 0.326722833 0.249198811 0.096558667 0.226531071 0.004900133
```

&nbsp;

### 4.3 Principal Component Analysis (PCA)

```r
# 4. PRINCIPAL COMPONENT ANALYSIS (PCA)
# Fit the PCA on the standardized variables
pca_fit <- prcomp(features_scaled)
pca_fit
```

```
>## Standard deviations (1, .., p=6):
>## [1] 1.5965253 1.3296016 1.0160129 0.5685466 0.4373664 0.3693911
>##
>## Rotation (n x k) = (6 x 6):
>##                    PC1         PC2         PC3         PC4         PC5
>## sd_export   0.06288292 -0.64122531 -0.35608319 -0.59664097  0.23963959
>## cv          0.30107137  0.60639737 -0.02059310 -0.33667194  0.65367780
>## r2_trend    0.49951229 -0.37653024  0.02338932  0.35827374  0.32682899
>## cagr        0.53861549  0.07461870  0.31671835 -0.50442501 -0.56020616
>## covid_drop -0.14794859 -0.26548056  0.87765100 -0.05989657  0.30377040
>## slope_rel   0.58642460 -0.05735359 -0.04064272  0.37984114 -0.04851414
>##                    PC6
>## sd_export   0.21135994
>## cv          0.02390654
>## r2_trend   -0.61072755
>## cagr       -0.18904855
>## covid_drop  0.20370554
>## slope_rel   0.71030417
```

I plot the explained variance per component (scree plot) and the biplot of regions and variables.

```r
# Plot the explained variance per component
plot_scree <- fviz_eig(pca_fit, addlabels = TRUE)
plot_scree
```

![Scree Plot](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Scree%20plot.png)

```r
# Plot the biplot of regions and variables
plot_pca <- fviz_pca_biplot(pca_fit, repel = TRUE,
                            title = "PCA: Biplot of Regions and Features")
plot_pca
```

![PCA Biplot](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20PCA%20Biplot%20of%20Regions%20and%20Features.png)

- **PC1 explains 42.5%**, **PC2 29.5%** and **PC3 17.2%** of the variance. The first two components explain about **72%** and the first three about **89%**.
- **PC1** is driven mainly by **growth and trend** variables (`slope_rel`, `cagr`, `r2_trend`). Regions on the right (Apurimac, Ayacucho, Puno, Cusco) grew the most, and regions on the left (Tacna, Pasco, Cajamarca, Moquegua) grew the least.
- **PC2** separates **size and volatility**. Lima, La Libertad, Arequipa and Ica (large in absolute terms, high `sd_export`) are at the bottom, and small and relatively volatile regions (Loreto, Huanuco, Amazonas, Huancavelica, Ucayali) are at the top, driven by `cv`.
- **PC3** is almost entirely explained by `covid_drop`, so the COVID-19 impact is a separate dimension from growth and size.

&nbsp;

### 4.4 Clustering

I use the Euclidean distance matrix and fit **hierarchical clustering with Ward's method (`ward.D2`)** and **K-Means** (`nstart = 25`) with the same number of clusters.

**Choosing k.** I use the elbow method and the average silhouette width. The elbow curve shows **no sharp bend**, and the silhouette is highest at **k = 5** (0.262). I therefore use **k = 5**. It is important to note that the silhouette values are low overall (from about 0.24 to 0.26), which means the cluster structure is **weak** and the groups should be read as a useful summary rather than sharply separated categories.

```r
k_clusters <- 5   # chosen from the silhouette peak (k = 5). The elbow plot shows no sharp bend
# 5.1 Compute the Euclidean distance matrix
dist_matrix <- dist(features_scaled, method = "euclidean")
set.seed(123)
plot_elbow <- fviz_nbclust(features_scaled, kmeans, method = "wss", nstart = 25) +
  labs(title = "Elbow Method")
plot_silhouette <- fviz_nbclust(features_scaled, kmeans, method = "silhouette", nstart = 25) +
  labs(title = "Average Silhouette Width")
plot_elbow
```

![Elbow Method](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Elbow%20Method.png)

```r
plot_silhouette
```

![Average Silhouette Width](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Average%20Silhouette%20Width.png)

Now I fit the hierarchical clustering and plot the dendrogram.

```r
# 5.2 Fit hierarchical clustering with Ward's method and plot the dendrogram
hc_fit <- hclust(dist_matrix, method = "ward.D2")
plot_dendro <- fviz_dend(hc_fit, k = k_clusters, rect = TRUE,
                         main = "Dendrogram of Exporting Regions")
plot_dendro
```

![Dendrogram of Exporting Regions](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Dendrogram%20of%20Exporting%20Regions.png)

I assign each region to a cluster (cutting the tree at k = 5) and fit K-Means with the same number of clusters.

```r
# 5.3 Assign each region to a cluster (cut the tree at k = 5)
hc_clusters <- cutree(hc_fit, k = k_clusters)
```

```r
# 5.4 Fit K-Means with the same number of clusters
set.seed(123)
kmeans_fit  <- kmeans(features_scaled, centers = k_clusters, nstart = 25)
plot_kmeans <- fviz_cluster(kmeans_fit, data = features_scaled, repel = TRUE,
                            main = paste0("K-Means Clusters (K = ", k_clusters, ")"))
plot_kmeans
```

![K-Means Clusters](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20K-Means%20Clusters%20%28K%20%3D%205%29.png)

Comparison between both methods:

```r
# 5.5 Compare both clustering results
cluster_comparison <- table(Hierarchical = hc_clusters, KMeans = kmeans_fit$cluster)
cluster_comparison
```

```
>##             KMeans
>## Hierarchical 1 2 3 4 5
>##            1 0 0 2 0 1
>##            2 0 6 1 0 0
>##            3 1 0 0 3 0
>##            4 7 0 0 0 0
>##            5 0 1 0 0 3
```

Both methods agree on **21 of 25 regions (84%)**. The differences are concentrated in borderline regions: Amazonas, Cusco, San Martin and Tumbes.

Now I save the cluster assignments and profile each K-Means cluster with the average of the features.

```r
# 5.6 Save cluster assignments and profile each cluster
cluster_results <- tibble(
  department     = rownames(features_scaled),
  hc_cluster     = as.integer(hc_clusters),
  kmeans_cluster = as.integer(kmeans_fit$cluster)
)
cluster_results
```

```
>## # A tibble: 25 × 3
>##    department   hc_cluster kmeans_cluster
>##    <chr>             <int>          <int>
>##  1 Amazonas              1              5
>##  2 Ancash                2              2
>##  3 Apurimac              3              4
>##  4 Arequipa              4              1
>##  5 Ayacucho              3              4
>##  6 Cajamarca             2              2
>##  7 Callao                4              1
>##  8 Cusco                 3              1
>##  9 Huancavelica          1              3
>## 10 Huanuco               5              5
>## # ℹ 15 more rows
```

```r
cluster_profile <- features_raw %>%
  left_join(cluster_results, by = "department") %>%
  group_by(kmeans_cluster) %>%
  summarise(n = n(), across(where(is.numeric) & !any_of("hc_cluster"), mean), .groups = "drop")
cluster_profile
```

```
>## # A tibble: 5 × 9
>##   kmeans_cluster     n mean_export sd_export    cv r2_trend   cagr covid_drop
>##            <int> <dbl>       <dbl>     <dbl> <dbl>    <dbl>  <dbl>      <dbl>
>## 1              1     8      276.      116.   0.492   0.507  0.106       0.402
>## 2              2     7      130.       52.3  0.464   0.0773 0.0329      0.400
>## 3              3     3        7.35      6.45 0.897   0.134  0.195       0.594
>## 4              4     3       57.6      63.9  1.07    0.635  0.281       0.260
>## 5              5     4        3.96      4.44 1.10    0.122  0.0719      0.122
>## # ℹ 1 more variable: slope_rel <dbl>
```

The K-Means groups and their average profile:

| Cluster | Regions | Mean export | CV | CAGR | COVID ratio | Profile |
|---|---|---|---|---|---|---|
| 1 | Lima, Callao, Arequipa, Ica, La Libertad, Piura, Lambayeque, Cusco | 276 | 0.49 | 10.6% | 0.40 | **Major exporting hubs**: large and relatively stable |
| 2 | Ancash, Cajamarca, Moquegua, Pasco, Junin, Tacna, Tumbes | 130 | 0.46 | 3.3% | 0.40 | **Mature, slow-growth regions**: mid-size with a weak trend |
| 3 | Huancavelica, San Martin, Madre de Dios | 7 | 0.90 | 19.5% | 0.59 | **Small, fast-growing regions**: small base, mildest COVID-19 drop |
| 4 | Apurimac, Ayacucho, Puno | 58 | 1.07 | 28.1% | 0.26 | **Emerging growth regions**: strongest trend and growth |
| 5 | Amazonas, Huanuco, Loreto, Ucayali | 4 | 1.10 | 7.2% | 0.12 | **Very small, volatile regions**: tiny base, strongest COVID-19 drop |

*COVID ratio is the mean of `covid_drop`: the lowest 2020 month divided by the 2019 monthly mean, so a lower value means a bigger drop.*

&nbsp;

### 4.5 Supervised classification

**Goal:** predict whether a region's exports in a given month will be **higher than in the same month of the previous year** (`beat_prev_year`, with "Yes" as the positive class).

**Predictors:**

| Predictor | Description |
|---|---|
| `lag_1`, `lag_3`, `lag_12` | Export value 1 month, 3 months and 12 months earlier (`lag_12` is the reference of the target). `lag_1` and `lag_3` are later removed by `step_corr()` |
| `gap_1_12` | `log1p(lag_1) - log1p(lag_12)`: how last month compared with the same month of last year |
| `month` | Month of the year (seasonality) |
| `department` | Region (one-hot encoded) |
| Regional features | `mean_export`, `sd_export`, `cv`, `slope_rel`, `r2_trend`, `cagr` (`mean_export` and `sd_export` are later removed by `step_corr()`) |

To **avoid data leakage**, the regional features used here are recomputed **using only the training years (before 2020)**, and `covid_drop` is excluded because it uses 2020 data. All the predictors are known before the month being predicted.

```r
# Target: compare with the same month of the previous year
# 6.1 Target, lagged predictors and seasonality
df_class <- df_model %>%
  arrange(department, date) %>%
  group_by(department) %>%
  mutate(
    lag_1  = lag(export_value, 1),     # Previous month
    lag_3  = lag(export_value, 3),     # Previous quarter
    lag_12 = lag(export_value, 12),    # Same month last year (the target's reference)
    beat_prev_year = factor(ifelse(export_value > lag_12, "Yes", "No"),
                            levels = c("Yes", "No")),   # "Yes" is the positive class
    gap_1_12 = log1p(lag_1) - log1p(lag_12),            # Last month vs. same month last year
    month    = factor(month(date))                      # Seasonality (unordered factor)
  ) %>%
  ungroup() %>%
  drop_na(beat_prev_year, lag_1, lag_3, lag_12)
```

```r
# Regional features computed only with training years (< 2020) to avoid leakage
features_train <- df_model %>%
  filter(year(date) < 2020) %>%
  arrange(department, date) %>%
  group_by(department) %>%
  mutate(t = row_number()) %>%
  summarise(
    mean_export = mean(export_value),
    sd_export   = sd(export_value),
    cv          = sd_export / mean_export,
    slope_rel   = coef(lm(export_value ~ t))[[2]] / mean_export,
    r2_trend    = summary(lm(export_value ~ t))$r.squared,
    cagr        = (sum(export_value[year(date) == 2019]) /
                     sum(export_value[year(date) == 2005]))^(1 / 14) - 1,
    .groups = "drop"
  )
df_class <- df_class %>%
  left_join(features_train, by = "department")
```

Class balance (all data):

```r
# 6.2 Check class balance
class_balance <- df_class %>%
  count(beat_prev_year) %>%
  mutate(prop = n / sum(n))
class_balance
```

```
>## # A tibble: 2 × 3
>##   beat_prev_year     n  prop
>##   <fct>          <int> <dbl>
>## 1 Yes             2974 0.583
>## 2 No              2126 0.417
```

I split the data **chronologically** (to avoid using the future to predict the past):

- **Train:** January 2006 to December 2019 (4,200 rows).
- **Test:** 2020 to 2022 (**900 rows**), which includes the COVID-19 drop and the rebound.

```r
# 6.3 Split the data chronologically to avoid data leakage
train_class <- df_class %>% filter(year(date) < 2020)
test_class  <- df_class %>% filter(year(date) >= 2020)
```

The preprocessing recipe creates dummy variables, removes zero-variance and highly correlated predictors (using only the training distribution) and normalizes numeric predictors.

```r
# 6.4 Define the preprocessing recipe
rec_class <- recipe(beat_prev_year ~ ., data = train_class) %>%
  update_role(date, export_value, new_role = "ID") %>%
  step_dummy(department, month, one_hot = TRUE) %>%
  step_zv(all_predictors()) %>%
  # Filter correlation and scale using only the train_class distribution
  step_corr(all_numeric_predictors(), threshold = 0.9) %>%
  step_normalize(all_numeric_predictors())
```

Four models are fitted, each in its own `workflow()`:

| Model | Engine | Main settings |
|---|---|---|
| Logistic regression | `glm` | default |
| Decision tree | `rpart` | `cost_complexity = 0.0001`, `tree_depth = 10` |
| Random forest | `ranger` | `trees = 500`, impurity importance |
| XGBoost | `xgboost` | `trees = 200` |

```r
# 6.5 Define the models
model_specs <- list(
  logistic      = logistic_reg() %>%
    set_engine("glm") %>% set_mode("classification"),
  decision_tree = decision_tree(cost_complexity = 0.0001, tree_depth = 10) %>%
    set_engine("rpart") %>% set_mode("classification"),
  random_forest = rand_forest(trees = 500) %>%
    set_engine("ranger", importance = "impurity") %>% set_mode("classification"),
  xgboost       = boost_tree(trees = 200) %>%
    set_engine("xgboost") %>% set_mode("classification")
)
```

```r
# 6.6 Fit every model within its own workflow
set.seed(123)
fits <- map(model_specs, function(spec) {
  workflow() %>%
    add_recipe(rec_class) %>%
    add_model(spec) %>%
    fit(data = train_class)
})
```

Then I predict on the test set (2020-2022).

```r
# 6.7 Predict on the test set (2020-2022)
results <- map(fits, function(fit) {
  test_class %>%
    select(beat_prev_year) %>%
    bind_cols(predict(fit, new_data = test_class, type = "prob")) %>%
    bind_cols(predict(fit, new_data = test_class))
})
results
```

```
>## $logistic
>## # A tibble: 900 × 4
>##    beat_prev_year .pred_Yes .pred_No .pred_class
>##    <fct>              <dbl>    <dbl> <fct>
>##  1 No                 0.837    0.163 Yes
>##  2 No                 0.344    0.656 No
>##  3 Yes                0.729    0.271 Yes
>##  4 No                 0.397    0.603 No
>##  5 Yes                0.578    0.422 Yes
>##  6 No                 0.368    0.632 No
>##  7 No                 0.227    0.773 No
>##  8 Yes                0.622    0.378 Yes
>##  9 Yes                0.752    0.248 Yes
>## 10 Yes                0.775    0.225 Yes
>## # ℹ 890 more rows
>##
>## $decision_tree
>## # A tibble: 900 × 4
>##    beat_prev_year .pred_Yes .pred_No .pred_class
>##    <fct>              <dbl>    <dbl> <fct>
>##  1 No                0.417    0.583  No
>##  2 No                0.0952   0.905  No
>##  3 Yes               0.917    0.0828 Yes
>##  4 No                0.132    0.868  No
>##  5 Yes               0.818    0.182  Yes
>##  6 No                0.0952   0.905  No
>##  7 No                0.0769   0.923  No
>##  8 Yes               0.457    0.543  No
>##  9 Yes               0.917    0.0828 Yes
>## 10 Yes               0.917    0.0828 Yes
>## # ℹ 890 more rows
>##
>## $random_forest
>## # A tibble: 900 × 4
>##    beat_prev_year .pred_Yes .pred_No .pred_class
>##    <fct>              <dbl>    <dbl> <fct>
>##  1 No                 0.670    0.330 Yes
>##  2 No                 0.312    0.688 No
>##  3 Yes                0.774    0.226 Yes
>##  4 No                 0.279    0.721 No
>##  5 Yes                0.666    0.334 Yes
>##  6 No                 0.318    0.682 No
>##  7 No                 0.420    0.580 No
>##  8 Yes                0.470    0.530 No
>##  9 Yes                0.517    0.483 Yes
>## 10 Yes                0.534    0.466 Yes
>## # ℹ 890 more rows
>##
>## $xgboost
>## # A tibble: 900 × 4
>##    beat_prev_year .pred_Yes .pred_No .pred_class
>##    <fct>              <dbl>    <dbl> <fct>
>##  1 No               0.900     0.1000 Yes
>##  2 No               0.138     0.862  No
>##  3 Yes              0.977     0.0228 Yes
>##  4 No               0.00876   0.991  No
>##  5 Yes              0.934     0.0661 Yes
>##  6 No               0.0305    0.969  No
>##  7 No               0.604     0.396  Yes
>##  8 Yes              0.456     0.544  No
>##  9 Yes              0.400     0.600  No
>## 10 Yes              0.612     0.388  Yes
>## # ℹ 890 more rows
```

&nbsp;

### 4.6 Model evaluation

I compute accuracy, balanced accuracy, precision, recall, F1, Cohen's kappa and ROC AUC on the 2020-2022 test set.

```r
# 7.1 Compute accuracy, precision, recall, F1 and AUC for each model
class_metrics <- metric_set(accuracy, bal_accuracy, precision, recall, f_meas, kap)
metrics_table <- imap_dfr(results, function(res, name) {
  bind_rows(
    class_metrics(res, truth = beat_prev_year, estimate = .pred_class),
    roc_auc(res, truth = beat_prev_year, .pred_Yes)
  ) %>%
    mutate(model = name)
}) %>%
  select(model, .metric, .estimate) %>%
  pivot_wider(names_from = .metric, values_from = .estimate) %>%
  arrange(desc(roc_auc))
metrics_table
```

```
>## # A tibble: 4 × 8
>##   model         accuracy bal_accuracy precision recall f_meas   kap roc_auc
>##   <chr>            <dbl>        <dbl>     <dbl>  <dbl>  <dbl> <dbl>   <dbl>
>## 1 logistic         0.754        0.750     0.842  0.765  0.802 0.481   0.827
>## 2 random_forest    0.77         0.754     0.832  0.808  0.820 0.501   0.827
>## 3 decision_tree    0.766        0.749     0.829  0.805  0.817 0.492   0.822
>## 4 xgboost          0.76         0.744     0.826  0.798  0.812 0.481   0.812
```

I also add a **baseline model that always predicts "Yes"**, because 64.9% of the test months are "Yes" (584 of 900).

```r
# Baseline: always predict "Yes"
baseline_pred <- test_class %>%
  transmute(beat_prev_year,
            .pred_class = factor("Yes", levels = c("Yes", "No")))
baseline_row <- class_metrics(baseline_pred, truth = beat_prev_year, estimate = .pred_class) %>%
  select(.metric, .estimate) %>%
  pivot_wider(names_from = .metric, values_from = .estimate) %>%
  mutate(model = "baseline_always_yes", roc_auc = 0.5)
metrics_table <- bind_rows(metrics_table, baseline_row) %>%
  arrange(desc(roc_auc))
metrics_table
```

```
>## # A tibble: 5 × 8
>##   model              accuracy bal_accuracy precision recall f_meas   kap roc_auc
>##   <chr>                 <dbl>        <dbl>     <dbl>  <dbl>  <dbl> <dbl>   <dbl>
>## 1 logistic              0.754        0.750     0.842  0.765  0.802 0.481   0.827
>## 2 random_forest         0.77         0.754     0.832  0.808  0.820 0.501   0.827
>## 3 decision_tree         0.766        0.749     0.829  0.805  0.817 0.492   0.822
>## 4 xgboost               0.76         0.744     0.826  0.798  0.812 0.481   0.812
>## 5 baseline_always_y…    0.649        0.5       0.649  1      0.787 0       0.5
```

Confusion matrices of each model:

```r
# 7.2 Compute the confusion matrix of each model
confusion_matrices <- map(results, ~ conf_mat(.x, truth = beat_prev_year,
                                              estimate = .pred_class))
confusion_matrices # Display the final comparison
```

```
>## $logistic
>##           Truth
>## Prediction Yes  No
>##        Yes 447  84
>##        No  137 232
>##
>## $decision_tree
>##           Truth
>## Prediction Yes  No
>##        Yes 470  97
>##        No  114 219
>##
>## $random_forest
>##           Truth
>## Prediction Yes  No
>##        Yes 472  95
>##        No  112 221
>##
>## $xgboost
>##           Truth
>## Prediction Yes  No
>##        Yes 466  98
>##        No  118 218
```

ROC curves of all models:

```r
# 7.3 Plot the ROC curves of all models together
plot_roc <- imap_dfr(results, function(res, name) {
  roc_curve(res, truth = beat_prev_year, .pred_Yes) %>%
    mutate(model = name)
}) %>%
  ggplot(aes(x = 1 - specificity, y = sensitivity, color = model)) +
  geom_path(linewidth = 1) +
  geom_abline(linetype = "dashed") +
  coord_equal() +
  theme_minimal() +
  labs(title = "ROC Curves by Model", x = "1 - Specificity", y = "Sensitivity")
plot_roc
```

![ROC Curves by Model](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20ROC%20Curves%20by%20Model.png)

- All four models **outperform the baseline**: about **10-12 percentage points** more accuracy, a balanced accuracy of **0.74-0.75** (baseline: 0.50) and a kappa of **0.48-0.50** (baseline: 0).
- The **ROC AUC is 0.81-0.83**, which indicates good but not excellent discrimination.
- The four models perform very similarly, so a more complex model does not give a clear advantage over logistic regression.
- The **random forest** has the best accuracy, balanced accuracy, F1 and kappa, and **logistic regression** has the highest precision.
- The 2020-2022 period is harder than a regular period because it contains the COVID-19 drop and the rebound, which changes the behavior learned before 2020.

&nbsp;

### 4.7 Variable importance

```r
# 7.4 Plot variable importance (Random Forest and Decision Tree)
plot_importance_rf <- fits$random_forest %>%
  extract_fit_engine() %>%
  ranger::importance() %>%
  enframe(name = "variable", value = "importance") %>%
  slice_max(importance, n = 15) %>%
  ggplot(aes(x = importance, y = reorder(variable, importance))) +
  geom_point(size = 3, color = "steelblue") +
  theme_minimal() +
  labs(title = "Variable Importance (Random Forest)", x = "Importance", y = NULL)
plot_importance_rf
```

![Variable Importance Random Forest](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Variable%20Importance%20%28Random%20Forest%29.png)

```r
plot_importance_tree <- fits$decision_tree %>%
  extract_fit_engine() %>%
  pluck("variable.importance") %>%
  enframe(name = "variable", value = "importance") %>%
  slice_max(importance, n = 15) %>%
  ggplot(aes(x = importance, y = reorder(variable, importance))) +
  geom_point(size = 3, color = "darkorange") +
  theme_minimal() +
  labs(title = "Variable Importance (Decision Tree)", x = "Importance", y = NULL)
plot_importance_tree
```

![Variable Importance Decision Tree](Peru%20Regional%20Export%20Trends%20%282005-2022%29%20Images/Plot%20-%20Variable%20Importance%20%28Decision%20Tree%29.png)

- In both models, **`gap_1_12` is by far the most important variable**, followed by **`lag_12`**. The model mainly learns **persistence**: if last month was already above the same month of the previous year, this month is likely to be above it too.
- The regional features (`slope_rel`, `cv`, `r2_trend`, `cagr`) come next, and the month and department dummy variables contribute very little. In the plots, `month_X1` to `month_X12` correspond to the months January to December.
- Four variables do not appear in the plots because `step_corr()` removed them for being highly correlated (|r| > 0.9): the regional `mean_export` and `sd_export`, and the lagged values `lag_1` and `lag_3` (correlations of about 0.94-0.96 with `lag_12` on the log scale). `gap_1_12` is kept because its correlation with the lags is low (|r| < 0.2).

&nbsp;

## Phase 5: Sharing insights from the analysis

**Key findings**:

- **The data is clean and internally consistent.** There are no missing values, 35 months with a value of exactly 0 (mostly in small regions) and, in every month, the 25 regions plus "No Registrado" add up to the national total.

- **Exports are highly concentrated.** Lima represents about **24%** of national exports and the top 5 regions about **60%**, while nine regions contribute less than 1% each.

- **Most regions grew, but not equally.** Between 2005 and 2022, Ayacucho (CAGR about 37%), Apurimac (28%), Huancavelica (27%) and Madre de Dios (22%) show the strongest relative growth, although mostly from a very small starting base. Huanuco and Tacna show flat or negative growth.

- **Regions can be grouped into 5 profiles**: major exporting hubs, mature slow-growth regions, small fast-growing regions, emerging growth regions (Apurimac, Ayacucho and Puno) and very small volatile regions. Hierarchical clustering and K-Means agree on 84% of the regions, although the silhouette values show that the structure is weak.

- **PCA shows that two dimensions summarize most of the information**: growth and trend (PC1) and size and volatility (PC2) explain about **72%** of the variance together.

- **The COVID-19 impact was uneven.** The very small and volatile regions (Amazonas, Huanuco, Loreto, Ucayali) had the largest drops in 2020, while small fast-growing regions (Huancavelica, San Martin, Madre de Dios) had the mildest. The `covid_drop` metric compares the lowest month of 2020 against the 2019 mean, so it is sensitive to volatile months.

- **Year-over-year growth can be predicted moderately well.** The best models reach an AUC of about **0.83** and a balanced accuracy of about **0.75** on 2020-2022, clearly above the "always Yes" baseline. Most of the predictive power comes from **persistence** (recent exports compared with the same month of the previous year) and not from seasonality or region identity.

**Limitations and next steps**:

- The models were evaluated on **one single chronological split**, without time-series cross-validation or hyperparameter tuning (`tune`). The next step would be to use rolling-origin resampling and tune the tree-based models.
- The predictors only use the past of each region's own series. Adding external variables such as **commodity prices** (copper, gold, etc.), the **exchange rate** or **global demand** could improve the predictions. 
- The clustering structure is weak (silhouette about 0.26) and the regional features are computed over a period that includes the COVID-19 shock, so the groups can change if another period or other features are used.
- Regional descriptive features are constant within each region, so they act partly as a regional "fingerprint" in the classifier.


&nbsp;

## Acknowledgements

The data used in this project comes from the *Banco Central de Reserva del Perú* (BCRP), Peru's central bank, through its statistical portal, in the section of monthly series of exports and imports: [BCRP: Statistics, Exports and Imports (monthly series)](https://estadisticas.bcrp.gob.pe/estadisticas/series/mensuales/exportaciones-e-importaciones).
