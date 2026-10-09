#' ---
#' title: "Peru Regional Export Trends (2005-2022) - ML Scripts"
#' author: "Kevin Arias"
#' date: "`r Sys.Date()`"
#' output: html_document
#' ---

# ==============================================================================
# ML SCRIPTS
# ==============================================================================

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
#+ fig.width=14, fig.height=10

# 1. DATA LOADING AND QUALITY CHECKS
# Load the clean long-format table produced by the cleaning script
df_long <- read_csv(
  here("Peru Regional Export Trends (2005-2022)","Peru Regional Export Trends (2005-2022) Clean Data - Long.csv"),
  col_types = cols(date = col_date(), department = col_character(), export_value = col_double())
)

# Keep the national total separately to compute regional shares
df_total <- df_long %>%
  filter(department == "Total")

# Remove "Total" and "No Registrado" to keep only real regions
df_model <- df_long %>%
  filter(!department %in% c("Total", "No Registrado"))

glimpse(df_model)
skim(df_model)

# 2. EXPLORATORY DATA ANALYSIS (EDA)
# 2.1 Plot one line chart per region
plot_lines <- df_model %>%
  ggplot(aes(x = date, y = export_value)) +
  geom_line() +
  facet_wrap(~ department, scales = "free_y") +
  theme_minimal() +
  labs(title = "Export Evolution by Region (2005-2022)", x = "Date", y = "Value")
plot_lines

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

# 2.3 Compute the average share of each region in national exports
df_share <- df_model %>%
  left_join(df_total %>% select(date, total_value = export_value), by = "date") %>%
  mutate(share = export_value / total_value) %>%
  group_by(department) %>%
  summarise(avg_share = mean(share, na.rm = TRUE), .groups = "drop")
print(df_share, n=25)

plot_share <- df_share %>%
  ggplot(aes(x = reorder(department, avg_share), y = avg_share)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() +
  labs(title = "Average Share of National Exports by Region", x = NULL, y = "Share")
plot_share


# 3. FEATURE ENGINEERING (one row per region)
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

# 3.2 Apply a log10 transformation to the variables with a skewed scale
features_log <- features_raw %>%
  mutate(
    mean_export = log10(mean_export + 1),
    sd_export   = log10(sd_export + 1)
  )
print(features_log, n=25)

# 3.3 Check collinearity among variables
cor_matrix <- features_log %>%
  select(-department) %>%
  cor()
cor_matrix

# 3.4 Discard highly correlated variables (|r| > 0.9)
corr_recipe <- recipe(~ ., data = features_log) %>%
  update_role(department, new_role = "id") %>%
  step_corr(all_numeric_predictors(), threshold = 0.9) %>%
  prep()

features_selected <- bake(corr_recipe, new_data = NULL)

# 3.5 Standardize variables (crucial because of different scales)
features_scaled <- features_selected %>%
  column_to_rownames("department") %>%
  scale()
features_scaled


# 4. PRINCIPAL COMPONENT ANALYSIS (PCA)
# Fit the PCA on the standardized variables
pca_fit <- prcomp(features_scaled)
pca_fit

# Plot the explained variance per component
plot_scree <- fviz_eig(pca_fit, addlabels = TRUE)
plot_scree

# Plot the biplot of regions and variables
plot_pca <- fviz_pca_biplot(pca_fit, repel = TRUE,
                            title = "PCA: Biplot of Regions and Features")
plot_pca


# 5. CLUSTERING

k_clusters <- 5   # chosen from the silhouette peak (k = 5).The elbow plot shows no sharp bend

# 5.1 Compute the Euclidean distance matrix
dist_matrix <- dist(features_scaled, method = "euclidean")

set.seed(123)

plot_elbow <- fviz_nbclust(features_scaled, kmeans, method = "wss", nstart = 25) +
  labs(title = "Elbow Method")
plot_silhouette <- fviz_nbclust(features_scaled, kmeans, method = "silhouette", nstart = 25) +
  labs(title = "Average Silhouette Width")
plot_elbow
plot_silhouette

# 5.2 Fit hierarchical clustering with Ward's method and plot the dendrogram
hc_fit <- hclust(dist_matrix, method = "ward.D2")
plot_dendro <- fviz_dend(hc_fit, k = k_clusters, rect = TRUE,
                         main = "Dendrogram of Exporting Regions")
plot_dendro

# 5.3 Assign each region to a cluster (cut the tree at k = 5)
hc_clusters <- cutree(hc_fit, k = k_clusters)

# 5.4 Fit K-Means with the same number of clusters
set.seed(123)
kmeans_fit  <- kmeans(features_scaled, centers = k_clusters, nstart = 25)
plot_kmeans <- fviz_cluster(kmeans_fit, data = features_scaled, repel = TRUE,
                            main = paste0("K-Means Clusters (K = ", k_clusters, ")"))
plot_kmeans

# 5.5 Compare both clustering results
cluster_comparison <- table(Hierarchical = hc_clusters, KMeans = kmeans_fit$cluster)
cluster_comparison

# 5.6 Save cluster assignments and profile each cluster
cluster_results <- tibble(
  department     = rownames(features_scaled),
  hc_cluster     = as.integer(hc_clusters),
  kmeans_cluster = as.integer(kmeans_fit$cluster)
)
cluster_results

cluster_profile <- features_raw %>%
  left_join(cluster_results, by = "department") %>%
  group_by(kmeans_cluster) %>%
  summarise(n = n(), across(where(is.numeric) & !any_of("hc_cluster"), mean), .groups = "drop")
cluster_profile


# 6. SUPERVISED CLASSIFICATION (Region-Month level)
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

# 6.2 Check class balance
class_balance <- df_class %>%
  count(beat_prev_year) %>%
  mutate(prop = n / sum(n))
class_balance

# 6.3 Split the data chronologically to avoid data leakage
train_class <- df_class %>% filter(year(date) < 2020)
test_class  <- df_class %>% filter(year(date) >= 2020)

# 6.4 Define the preprocessing recipe
rec_class <- recipe(beat_prev_year ~ ., data = train_class) %>%
  update_role(date, export_value, new_role = "ID") %>% 
  step_dummy(department, month, one_hot = TRUE) %>%
  step_zv(all_predictors()) %>%
  # Filter correlation and scale using only the train_class distribution
  step_corr(all_numeric_predictors(), threshold = 0.9) %>%
  step_normalize(all_numeric_predictors())

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

# 6.6 Fit every model within its own workflow
set.seed(123)
fits <- map(model_specs, function(spec) {
  workflow() %>%
    add_recipe(rec_class) %>%
    add_model(spec) %>%
    fit(data = train_class)
})

# 6.7 Predict on the test set (2020-2022)
results <- map(fits, function(fit) {
  test_class %>%
    select(beat_prev_year) %>%
    bind_cols(predict(fit, new_data = test_class, type = "prob")) %>%
    bind_cols(predict(fit, new_data = test_class))
})
results


# 7. MODEL EVALUATION
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

# 7.2 Compute the confusion matrix of each model
confusion_matrices <- map(results, ~ conf_mat(.x, truth = beat_prev_year,
                                              estimate = .pred_class))
confusion_matrices # Display the final comparison

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

