#!/usr/bin/env Rscript

# ==============================================================================
# SCRIPT TO GENERATE SCATTER PLOTS WITH FLEXIBLE REGRESSION MODELS
# Description: Plots relationships between two metrics (e.g., MPKI vs IPC).
#
# Examples:
#   1. Default Linear:
#      Rscript data-graphing/plot_scatter.R -c BigO3
#
#   2. Inverse Regression (Recommended for IPC vs MPKI):
#      Rscript data-graphing/plot_scatter.R -c BigO3 --model inverse
#
#   3. Local Smoothing (Data driven):
#      Rscript data-graphing/plot_scatter.R -c BigO3 --model loess
# ==============================================================================

suppressPackageStartupMessages({
  library(optparse)
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
})

# --- 1. Args ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Folder containing CSV files [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="scatter_plot.png",
              help="Output filename [default %default]", metavar="FILE"),
  
  make_option(c("-x", "--x_metric"), type="character", default="MPKI",
              help="Metric for X-axis [default %default]", metavar="STR"),
  
  make_option(c("-y", "--y_metric"), type="character", default="IPC",
              help="Metric for Y-axis [default %default]", metavar="STR"),
  
  make_option(c("-c", "--cores"), type="character", default="ALL",
              help="List of Cores to include [default %default]", metavar="LIST"),
  
  make_option(c("-p", "--predictors"), type="character", default="ALL",
              help="List of Predictors to include [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Optional list of SPEC app numbers to filter.", metavar="LIST"),
  
  # NEW ARGUMENT: Regression Model
  make_option(c("-M", "--model"), type="character", default="linear",
              help="Regression type: 'linear', 'inverse' (1/x), 'log', or 'loess' (smooth) [default %default]", metavar="STR")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Data Load ---

files <- list.files(path = opt$input, pattern = "*.csv", full.names = TRUE)

if(length(files) == 0) stop("No .csv files found.")

all_data <- data.frame()

for (f in files) { 
  fname <- basename(f)
  clean_name <- str_remove(str_remove(fname, "tagescl_data_"), ".csv")
  parts <- str_split(clean_name, "_", n = 2)[[1]]
  
  temp_df <- read_csv(f, show_col_types = FALSE)
  temp_df$Core <- parts[1]
  temp_df$Predictor <- parts[2]
  all_data <- bind_rows(all_data, temp_df)
}

# --- 3. Processing ---

all_data <- all_data %>%
  mutate(App_Num = str_extract(App, "^[0-9]+"))

suppressWarnings({
  all_data$IPC <- as.numeric(as.character(all_data$IPC))
  all_data$Sim_Is <- as.numeric(as.character(all_data$Sim_Is))
  all_data$total_cond_predicts <- as.numeric(as.character(all_data$total_cond_predicts))
  all_data$wrong_cond_predicts <- as.numeric(as.character(all_data$wrong_cond_predicts))
})

all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

if (!(opt$x_metric %in% colnames(all_data)) | !(opt$y_metric %in% colnames(all_data))) {
  stop("Metric not found in data.")
}

# --- 4. Filtering ---

if (opt$cores != "ALL") {
  all_data <- all_data %>% filter(Core %in% unlist(str_split(opt$cores, ",")))
}
if (opt$predictors != "ALL") {
  all_data <- all_data %>% filter(Predictor %in% unlist(str_split(opt$predictors, ",")))
}
if (!is.null(opt$apps)) {
  all_data <- all_data %>% filter(App_Num %in% unlist(str_split(opt$apps, ",")))
}

if (nrow(all_data) == 0) stop("No data left to plot.")

# --- 5. Generate Scatter Plot ---

p <- ggplot(all_data, aes(x = .data[[opt$x_metric]], 
                          y = .data[[opt$y_metric]], 
                          color = Predictor, 
                          shape = Predictor)) +
  # Points
  geom_point(size = 3, alpha = 0.7) +
  # Faceting by Core
  facet_wrap(~Core, scales = "free") +
  theme_bw(base_size = 14)

# --- REGRESSION LOGIC ---

if (opt$model == "linear") {
  # Standard line: y = mx + b
  p <- p + geom_smooth(method = "lm", formula = y ~ x, se = FALSE, size = 1.2)
  model_title <- "Linear Fit"

} else if (opt$model == "inverse") {
  # Inverse: y = a + b/x
  # We assume x is not 0. If x can be 0, this might crash or produce artifacts.
  p <- p + geom_smooth(method = "lm", formula = y ~ I(1/x), se = FALSE, size = 1.2)
  model_title <- "Inverse Fit (1/x)"

} else if (opt$model == "log") {
  # Logarithmic: y = a + b*ln(x)
  p <- p + geom_smooth(method = "lm", formula = y ~ log(x), se = FALSE, size = 1.2)
  model_title <- "Logarithmic Fit"

} else if (opt$model == "loess") {
  # Local Smoothing (Data driven curve)
  p <- p + geom_smooth(method = "loess", se = FALSE, size = 1.2)
  model_title <- "Loess Smooth"
}

# Labels and Theme
p <- p + labs(
    title = paste("Correlation:", opt$y_metric, "vs", opt$x_metric),
    subtitle = paste("Model:", model_title, "| Each point is a SPEC Benchmark"),
    x = opt$x_metric,
    y = opt$y_metric
  ) +
  theme(
    axis.text = element_text(size = 12),
    legend.position = "top",
    strip.text = element_text(face = "bold", size = 14)
  )

# --- 6. Save ---
ggsave(opt$output, plot = p, width = 10, height = 8)
cat(paste("Scatter plot saved:", opt$output, "\n"))