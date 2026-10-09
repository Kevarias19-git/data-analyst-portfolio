Peru Regional Export Trends (2005-2022): Exploratory Analysis and Machine Learning Using RStudio
================
By Kevin Arias


## Project Overview

This exploratory analysis is a personal portfolio project. I selected this topic because my interest in international trade and the Peruvian economy. In this project, I use *RStudio* for the entire process, from data preparation to machine learning, with the `tidyverse` for wrangling and plotting and the `tidymodels` framework for modeling.

The dataset comes from the *Banco Central de Reserva del Perú* (BCRP) statistical portal, in the section of monthly series of exports and imports [BCRP: Statistics, Exports and Imports (monthly series)](https://estadisticas.bcrp.gob.pe/estadisticas/series/mensuales/exportaciones-e-importaciones). It contains **monthly export values** for **25 regions** (24 departments plus Callao) from **January 2005 to December 2022** (216 months), plus the national **"Total"** and a **"No Registrado"** (not registered) category. The values are expressed in millions of US$ FOB. Everything starts with the file *Peru Regional Export Trends (2005-2022) Clean Data - Long.csv*, the result of a preliminary cleaning script, which transformed the original file into a long-format table with three columns: `date`, `department`, and `export_value`.

The main **objective** is to identify patterns, groups of similar regions and predictable behavior in Peru's regional exports, using both unsupervised (PCA and clustering) and supervised (classification) techniques.

For readability, I have divided this project into **5 phases** as follows:

- **Phase 1:** Understanding data.

- **Phase 2:** Cleaning and preparing data.

- **Phase 3:** Exploratory data analysis (EDA).

- **Phase 4:** Machine learning: feature engineering, PCA, clustering and classification.

- **Phase 5:** Sharing insights from the analysis.


&nbsp;

## Phase 1: Understanding data

### 1.1 Loading packages used in this analysis

I will import the following libraries:

- **tidyverse** and **lubridate** for reading files, wrangling data, handling dates and plotting with `ggplot2`.
- **tidymodels** for preprocessing recipes, model specifications, workflows and evaluation metrics.
- **factoextra** for visualizing PCA and clustering results.
- **skimr** for a quick summary of the data.
- **here** for building file paths relative to the project folder.


&nbsp;

### 1.2 Importing data

The clean long-format table produced by the cleaning script is imported with `read_csv()`, defining the column types explicitly (`date`, `department`, `export_value`).

```r
df_long <- read_csv(here("Peru Regional Export Trends (2005-2022)","Peru Regional Export Trends (2005-2022) Clean Data - Long.csv"),
  col_types = cols(date = col_date(), department = col_character(), export_value = col_double())
)
```
> ```
> ## A tibble: 5,832 × 3
> ##    date       department   export_value
> ##    <date>     <chr>               <dbl>
> ##  1 2005-01-01 Amazonas          0.177  
> ##  2 2005-01-01 Ancash          189.     
> ##  3 2005-01-01 Apurimac          0.00462
> ##  4 2005-01-01 Arequipa         27.9    
> ##  5 2005-01-01 Ayacucho          0.236  
> ##  6 2005-01-01 Cajamarca        83.8    
> ##  7 2005-01-01 Callao           94.5    
> ##  8 2005-01-01 Cusco            29.0    
> ##  9 2005-01-01 Huancavelica      0      
> ## 10 2005-01-01 Huanuco           0.0896 
> ## ℹ 5,822 more rows 
> ```

&nbsp;

### 1.3 Reviewing the imported data

Two data frames are created from the original table:

- `df_total` keeps the national **"Total"** series, which is used later to compute each region's share of national exports.
- `df_model` removes **"Total"** and **"No Registrado"** so that only real regions remain.

I then use `glimpse()` and `skim()` to understand the structure of `df_model`.

```r
df_total <- df_long %>% filter(department == "Total")
```
```
# A tibble: 216 × 3
   date       department export_value
   <date>     <chr>             <dbl>
 1 2005-01-01 Total             1264.
 2 2005-02-01 Total             1137.
 3 2005-03-01 Total             1347.
 4 2005-04-01 Total             1258.
 5 2005-05-01 Total             1355.
 6 2005-06-01 Total             1422.
 7 2005-07-01 Total             1558.
 8 2005-08-01 Total             1492.
 9 2005-09-01 Total             1505.
10 2005-10-01 Total             1469.
# ℹ 206 more rows
```

```r
df_model <- df_long %>% filter(!department %in% c("Total", "No Registrado"))
```
```
# A tibble: 5,400 × 3
   date       department   export_value
   <date>     <chr>               <dbl>
 1 2005-01-01 Amazonas          0.177  
 2 2005-01-01 Ancash          189.     
 3 2005-01-01 Apurimac          0.00462
 4 2005-01-01 Arequipa         27.9    
 5 2005-01-01 Ayacucho          0.236  
 6 2005-01-01 Cajamarca        83.8    
 7 2005-01-01 Callao           94.5    
 8 2005-01-01 Cusco            29.0    
 9 2005-01-01 Huancavelica      0      
10 2005-01-01 Huanuco           0.0896 
# ℹ 5,390 more rows
```

```r
glimpse(df_model)
```

```
Rows: 5,400
Columns: 3
$ date         <date> 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-01, 2005-01-01, 20…
$ department   <chr> "Amazonas", "Ancash", "Apurimac", "Arequipa", "Ayacucho", "Cajamarca", "Cal…
$ export_value <dbl> 0.17747598, 188.67116525, 0.00462130, 27.92751664, 0.23633488, 83.76016196,…
```

```r
skim(df_model)
```

```
Data summary Name 	df_model
Number of rows 	5400
Number of columns 	3
_______________________ 	
Column type frequency: 	
character 	1
Date 	1
numeric 	1
________________________ 	
Group variables 	None

Variable type: character
skim_variable 	n_missing 	complete_rate 	min 	max 	empty 	n_unique 	whitespace
department 	0 	1 	3 	13 	0 	25 	0

Variable type: Date
skim_variable 	n_missing 	complete_rate 	min 	max 	median 	n_unique
date 	0 	1 	2005-01-01 	2022-12-01 	2013-12-16 	216

Variable type: numeric
skim_variable 	n_missing 	complete_rate 	mean 	sd 	p0 	p25 	p50 	p75 	p100 	hist
export_value 	0 	1 	133.11 	194.14 	0 	6.83 	48.53 	198.76 	1696.54 	▇▁▁▁▁
```

Here is a quick observation:

- `df_model` has **5,400 rows and 3 columns** (25 regions x 216 months).
- There are **no missing values** in any column (complete rate = 1).
- Dates range from **2005-01-01 to 2022-12-01**, with 216 unique months.
- The mean monthly export value is **133.11** with a standard deviation of **194.14**. The median (**48.53**) is far below the mean and the maximum is **1,696.54**, so the distribution is **strongly right-skewed**. This is expected because a few regions export much more than the rest.
- The minimum value is **0**, so some region-months have no exports. [Confirm which regions and periods have zeros and whether they are real zeros or missing data in the BCRP source.]

&nbsp;

## Phase 2: Cleaning and preparing data

The cleaning was done in a separate script ([INSERT LINK: cleaning script in the repository]) that produced the long-format file used here. In summary, it:

- [Describe the raw BCRP file format, e.g., wide table with one column per region and one row per month.]
- [Describe how the dates were built and converted to `Date`.]
- [Describe name standardization, e.g., removing accents and capitalization such as "Madre De Dios".]
- [Describe how missing values, duplicates or unit issues were handled.]
- [Describe the pivot from wide to long format.]

[INSERT IMAGE: R code - key steps of the cleaning script (optional)]

In this script, the preparation steps are:

1. Separating the national total from the regional data (section 1.3).
2. Excluding **"No Registrado"**, which is not a real geographic region.
3. Building the modeling tables used in Phase 4 (a feature table with one row per region and a classification table with one row per region-month).

&nbsp;

## Phase 3: Exploratory data analysis (EDA)

### 3.1 Export evolution by region

I plot one line chart per region (`facet_wrap` with a free y-axis) to see each region's trajectory over time.

[INSERT IMAGE: R code - `plot_lines`]

[INSERT IMAGE: Plot - Export Evolution by Region (2005-2022)]

Here are some insights we can draw from the charts:

- Most regions show an **upward trend** over the period, for example Arequipa, Ica, La Libertad, Lambayeque, Cusco and Puno.
- **Apurimac** is almost flat until about **2015-2016** and then jumps sharply. [Add the cause if you verified it, e.g., start of a large mining operation.]
- **Ayacucho** shows a clear step up around **2020-2021**. [Add the cause if you verified it.]
- **Huancavelica, Huanuco and Pasco** peak in the early and mid 2010s and then decline.
- Several regions show a **sharp drop around 2020** (COVID-19), for example Lima, Callao, Arequipa, Ica and Ancash.
- Because each panel uses its own scale, the charts compare **shapes**, not **sizes**.

&nbsp;

### 3.2 Monthly heatmap for one region (Arequipa)

To look for seasonality, I build a month vs. year heatmap for **Arequipa**.

[INSERT IMAGE: R code - `plot_heatmap_Arequipa`]

[INSERT IMAGE: Plot - Monthly Heatmap - Arequipa]

- The color changes much more from **top to bottom (years)** than from **left to right (months)**, so the **long-term growth** dominates over any seasonal pattern.
- A clear dip appears in **April 2020**, which matches the COVID-19 lockdown.
- The highest values appear in **2021 and 2022**.

&nbsp;

### 3.3 Average share of each region in national exports

I join each region with the national total by date, compute its monthly share and then average it over the whole period.

[INSERT IMAGE: R code - `df_share` and `plot_share`]

[INSERT IMAGE: R output - `df_share` table (25 rows)]

[INSERT IMAGE: Plot - Average Share of National Exports by Region]

| Region | Average share |
|---|---|
| Lima | 24.2% |
| Ancash | 10.3% |
| Ica | 8.7% |
| Arequipa | 8.5% |
| Callao | 8.2% |

- **Lima** alone represents about **a quarter** of national exports.
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

These descriptive features use the **full period** and are used **only for PCA and clustering**, not for the classifier (see section 4.5).

[INSERT IMAGE: R code - `features_raw`]

[INSERT IMAGE: R output - `features_raw` table (25 x 8)]

I then apply a **log10(x + 1)** transformation to `mean_export` and `sd_export`, because their scales are very skewed (from about 4 to 800).

[INSERT IMAGE: R code - `features_log`]

&nbsp;

### 4.2 Checking collinearity and standardizing

I compute the correlation matrix and remove highly correlated variables (|r| > 0.9) with `step_corr()`. `mean_export` and `sd_export` have a correlation of **0.98**, so `mean_export` is removed and **6 variables** remain: `sd_export`, `cv`, `r2_trend`, `cagr`, `covid_drop` and `slope_rel`. These are standardized with `scale()` because the variables have very different scales.

[INSERT IMAGE: R code - `cor_matrix`, `corr_recipe` and `features_scaled`]

[INSERT IMAGE: R output - correlation matrix]

&nbsp;

### 4.3 Principal Component Analysis (PCA)

[INSERT IMAGE: R code - `prcomp()`, scree plot and biplot]

[INSERT IMAGE: Plot - Scree plot]

[INSERT IMAGE: Plot - PCA Biplot of Regions and Features]

- **PC1 explains 42.5%**, **PC2 29.5%** and **PC3 17.2%** of the variance. The first two components explain about **72%** and the first three about **89%**.
- **PC1** is driven mainly by **growth and trend** variables (`slope_rel`, `cagr`, `r2_trend`). Regions on the right (Apurimac, Ayacucho, Puno, Cusco) grew the most, and regions on the left (Tacna, Pasco, Cajamarca, Moquegua) grew the least.
- **PC2** separates **size and volatility**. Lima, La Libertad, Arequipa and Ica (large in absolute terms, high `sd_export`) are at the bottom, and small and relatively volatile regions (Loreto, Huanuco, Amazonas, Huancavelica, Ucayali) are at the top, driven by `cv`.
- **PC3** is almost entirely explained by `covid_drop`, so the COVID-19 impact is a separate dimension from growth and size.

&nbsp;

### 4.4 Clustering

I use the Euclidean distance matrix and fit **hierarchical clustering with Ward's method (`ward.D2`)**, and then **K-Means** (`nstart = 25`) with the same number of clusters.

**Choosing k.** I use the elbow method and the average silhouette width. The elbow curve shows **no sharp bend**, and the silhouette is highest at **k = 5** (0.262). I therefore use **k = 5**. It is important to note that the silhouette values are low overall (from about 0.24 to 0.26), which means the cluster structure is **weak** and the groups should be read as a useful summary rather than sharply separated categories.

[INSERT IMAGE: R code - `k_clusters`, `dist_matrix`, `plot_elbow` and `plot_silhouette`]

[INSERT IMAGE: Plot - Elbow Method]

[INSERT IMAGE: Plot - Average Silhouette Width]

[INSERT IMAGE: R code - `hc_fit`, `hc_clusters`, `kmeans_fit`]

[INSERT IMAGE: Plot - Dendrogram of Exporting Regions]

[INSERT IMAGE: Plot - K-Means Clusters (K = 5)]

Comparison between both methods:

|  | KMeans 1 | KMeans 2 | KMeans 3 | KMeans 4 | KMeans 5 |
|---|---|---|---|---|---|
| **Hierarchical 1** | 0 | 0 | 2 | 0 | 1 |
| **Hierarchical 2** | 0 | 6 | 1 | 0 | 0 |
| **Hierarchical 3** | 1 | 0 | 0 | 3 | 0 |
| **Hierarchical 4** | 7 | 0 | 0 | 0 | 0 |
| **Hierarchical 5** | 0 | 1 | 0 | 0 | 3 |

Both methods agree on **21 of 25 regions (84%)**. The differences are concentrated in borderline regions Cusco, Tumbes, San Martin and Amazonas. [Verify the exact regions with `cluster_results`, which has both assignments per region.]

[INSERT IMAGE: R code - `cluster_comparison`, `cluster_results` and `cluster_profile`]

[INSERT IMAGE: R output - `cluster_comparison` and `cluster_profile`]

The K-Means groups and their average profile:

| Cluster | Regions | Mean export | CV | CAGR | COVID ratio | Profile |
|---|---|---|---|---|---|---|
| 1 | Lima, Callao, Arequipa, Ica, La Libertad, Piura, Lambayeque, Cusco | 276 | 0.49 | 10.6% | 0.40 | **Major exporting hubs**: large and relatively stable |
| 2 | Ancash, Cajamarca, Moquegua, Pasco, Junin, Tacna, Tumbes | 130 | 0.46 | 3.3% | 0.40 | **Mature, slow-growth regions**: mid-size with a weak trend |
| 3 | Huancavelica, San Martin, Madre de Dios | 7 | 0.90 | 19.5% | 0.59 | **Small, fast-growing regions**: small base, mildest COVID-19 drop |
| 4 | Apurimac, Ayacucho, Puno | 58 | 1.07 | 28.1% | 0.26 | **Emerging growth regions**: strongest trend and growth |
| 5 | Amazonas, Huanuco, Loreto, Ucayali | 4 | 1.10 | 7.2% | 0.12 | **Very small, volatile regions**: tiny base, strongest COVID-19 drop |

[Adjust the cluster names if you prefer others. "COVID ratio" is the `covid_drop` mean: the lowest 2020 month divided by the 2019 monthly mean, so lower means a bigger drop.]

&nbsp;

### 4.5 Supervised classification

**Goal:** predict whether a region's exports in a given month will be **higher than in the same month of the previous year** (`beat_prev_year`, with "Yes" as the positive class).

**Predictors:**

| Predictor | Description |
|---|---|
| `lag_1`, `lag_3`, `lag_12` | Export value 1 month, 3 months and 12 months earlier (`lag_12` is the reference of the target) |
| `gap_1_12` | `log1p(lag_1) - log1p(lag_12)`: how last month compared with the same month of last year |
| `month` | Month of the year (seasonality) |
| `department` | Region (one-hot encoded) |
| Regional features | `mean_export`, `sd_export`, `cv`, `slope_rel`, `r2_trend`, `cagr` |

To **avoid data leakage**, the regional features used here are recomputed **using only the training years (before 2020)**, and `covid_drop` is excluded because it uses 2020 data. All the predictors are known before the month being predicted.

[INSERT IMAGE: R code - `df_class` (target, lags, month) and `features_train`]

Class balance (all data):

| beat_prev_year | n | proportion |
|---|---|---|
| Yes | 2,974 | 58.3% |
| No | 2,126 | 41.7% |

**Chronological split** (to avoid using the future to predict the past):

- **Train:** January 2006 to December 2019 (4,200 rows).
- **Test:** 2020 to 2022 (**900 rows**), which includes the COVID-19 drop and the rebound.

The preprocessing recipe creates dummy variables, removes zero-variance and highly correlated predictors (using only the training distribution) and normalizes numeric predictors. Four models are fitted, each in its own `workflow()`:

| Model | Engine | Main settings |
|---|---|---|
| Logistic regression | `glm` | default |
| Decision tree | `rpart` | `cost_complexity = 0.0001`, `tree_depth = 10` |
| Random forest | `ranger` | `trees = 500`, impurity importance |
| XGBoost | `xgboost` | `trees = 200` |

[INSERT IMAGE: R code - class balance, split, `rec_class`, `model_specs` and `fits`]

[INSERT IMAGE: R output - predictions on the test set (`results`)]

&nbsp;

### 4.6 Model evaluation

I compute accuracy, balanced accuracy, precision, recall, F1, Cohen's kappa and ROC AUC on the 2020-2022 test set. I also add a **baseline model that always predicts "Yes"**, because 64.9% of the test months are "Yes" (584 of 900).

[INSERT IMAGE: R code - `class_metrics`, `metrics_table`, baseline, `confusion_matrices` and `plot_roc`]

| Model | Accuracy | Balanced accuracy | Precision | Recall | F1 | Kappa | ROC AUC |
|---|---|---|---|---|---|---|---|
| Random forest | 0.770 | 0.754 | 0.832 | 0.808 | 0.820 | 0.501 | 0.827 |
| Logistic regression | 0.754 | 0.750 | 0.842 | 0.765 | 0.802 | 0.481 | 0.827 |
| Decision tree | 0.766 | 0.749 | 0.829 | 0.805 | 0.817 | 0.492 | 0.822 |
| XGBoost | 0.760 | 0.744 | 0.826 | 0.798 | 0.812 | 0.481 | 0.812 |
| Baseline (always "Yes") | 0.649 | 0.500 | 0.649 | 1.000 | 0.787 | 0.000 | 0.500 |

[INSERT IMAGE: R output - `metrics_table`]

[INSERT IMAGE: R output - confusion matrices]

[INSERT IMAGE: Plot - ROC Curves by Model]

- All four models **outperform the baseline**: about **10-12 percentage points** more accuracy, a balanced accuracy of **0.74-0.75** (baseline: 0.50) and a kappa of **0.48-0.50** (baseline: 0).
- The **ROC AUC is 0.81-0.83**, which indicates good but not excellent discrimination.
- The four models perform very similarly, so a more complex model does not give a clear advantage over logistic regression.
- The **random forest** has the best accuracy, balanced accuracy, F1 and kappa, and **logistic regression** has the highest precision.
- The 2020-2022 period is harder than a regular period because it contains the COVID-19 drop and the rebound, which changes the behavior learned before 2020.

&nbsp;

### 4.7 Variable importance

[INSERT IMAGE: R code - `plot_importance_rf` and `plot_importance_tree`]

[INSERT IMAGE: Plot - Variable Importance (Random Forest)]

[INSERT IMAGE: Plot - Variable Importance (Decision Tree)]

- In both models, **`gap_1_12` is by far the most important variable**, followed by **`lag_12`**. The model mainly learns **persistence**: if last month was already above the same month of the previous year, this month is likely to be above it too.
- The regional features (`slope_rel`, `cv`, `r2_trend`, `cagr`) come next, and the month and department dummy variables contribute very little. In the plots, `month_X1` to `month_X12` correspond to the months January to December.
- [Some regional variables such as `mean_export` or `sd_export` do not appear because `step_corr()` removed highly correlated predictors. Verify which ones were removed.]

&nbsp;

## Phase 5: Sharing insights from the analysis

**Key findings**:

- **Exports are highly concentrated.** Lima represents about **24%** of national exports and the top 5 regions about **60%**, while nine regions contribute less than 1% each.

- **Most regions grew, but not equally.** Between 2005 and 2022, Ayacucho (CAGR about 37%), Apurimac (28%), Huancavelica (27%) and Madre de Dios (22%) show the strongest relative growth, although mostly from a very small starting base. Huanuco and Tacna show flat or negative growth.

- **Regions can be grouped into 5 profiles**: major exporting hubs, mature slow-growth regions, small fast-growing regions, emerging growth regions (Apurimac, Ayacucho and Puno) and very small volatile regions. Hierarchical clustering and K-Means agree on 84% of the regions, although the silhouette values show that the structure is weak.

- **PCA shows that two dimensions summarize most of the information**: growth and trend (PC1) and size and volatility (PC2) explain about **72%** of the variance together.

- **The COVID-19 impact was uneven.** The very small and volatile regions (Amazonas, Huanuco, Loreto, Ucayali) had the largest drops in 2020, while small fast-growing regions (Huancavelica, San Martin, Madre de Dios) had the mildest. [Interpret with care: the `covid_drop` metric compares the lowest month of 2020 against the 2019 mean, so it is sensitive to volatile months.]

- **Year-over-year growth can be predicted moderately well.** The best models reach an AUC of about **0.83** and a balanced accuracy of about **0.75** on 2020-2022, clearly above the "always Yes" baseline. Most of the predictive power comes from **persistence** (recent exports compared with the same month of the previous year) and not from seasonality or region identity.

**Limitations and next steps**:

- The models were evaluated on **one single chronological split**, without time-series cross-validation or hyperparameter tuning (`tune`). The next step would be to use rolling-origin resampling and tune the tree-based models.
- The predictors only use the past of each region's own series. Adding external variables such as **commodity prices** (copper, gold, etc.), the **exchange rate** or **global demand** could improve the predictions. [Add other variables you consider relevant.]
- The clustering structure is weak (silhouette about 0.26) and the regional features are computed over a period that includes the COVID-19 shock, so the groups can change if another period or other features are used.
- Regional descriptive features are constant within each region, so they act partly as a regional "fingerprint" in the classifier.
- [Any other limitation: revisions of the BCRP data, unit of measure, "No Registrado" exports, zero values, etc.]

&nbsp;


## Acknowledge

The data used in this project comes from the Banco Central de Reserva del Perú (BCRP), Peru’s central bank, through its statistical portal, in the section of monthly series of exports and imports: [BCRP: Estadísticas, Exportaciones e Importaciones (series mensuales)](https://estadisticas.bcrp.gob.pe/estadisticas/series/mensuales/exportaciones-e-importaciones).
