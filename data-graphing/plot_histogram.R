#!/usr/bin/env Rscript

# ==============================================================================
# SCRIPT TO GENERATE COMPARATIVE BAR GRAPHS
# Example: $ Rscript data-graphing/plot_histogram.R -i 2-parser-output/ -o graf.png -m CondMissRate
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
              help="Carpeta donde están los CSVs generados por el parser [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico_comparativo.png",
              help="Nombre del archivo de imagen de salida [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica a graficar en eje Y (IPC, MPKI, CondMissRate, etc.) [default %default]", metavar="STR"),
  
  make_option(c("-c", "--cores"), type="character", default="ALL",
              help="Lista de Cores a incluir separados por coma (ej: 'BigO3,CVA6') o 'ALL' [default %default]", metavar="LIST"),
  
  make_option(c("-p", "--predictors"), type="character", default="ALL",
              help="Lista de Predictores a incluir separados por coma (ej: 'TAGE_L,LocalBP') o 'ALL' [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="List of SPEC app numbers to plot (e.g., '502,505,519'). If NULL, plots Geomean of all.", metavar="LIST")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Aux functions ---

# Geometric mean
geomean <- function(x) {
  exp(mean(log(x[x > 0]), na.rm = TRUE))
}

# --- 3. Data load ---

files <- list.files(path = opt$input, pattern = "*.csv", full.names = TRUE)

if(length(files) == 0) {
  stop("No se encontraron archivos .csv en el directorio indicado.")
}

all_data <- data.frame()

for (f in files) { 
  # Expected format from the parser: tagescl_data_CORE_PREDICTOR.csv
  
  fname <- basename(f)
  clean_name <- str_remove(fname, "tagescl_data_")
  clean_name <- str_remove(clean_name, ".csv")
  
  # Assume first underscore separates Core and Predictorst element after underscore is the Core, 
  # rest is the Predictor
  parts <- str_split(clean_name, "_", n = 2)[[1]]
  core_name <- parts[1]
  pred_name <- parts[2]
  
  # Read CSV
  temp_df <- read_csv(f, show_col_types = FALSE)
  
  # Add metadata columns
  temp_df$Core <- core_name
  temp_df$Predictor <- pred_name
  
  all_data <- bind_rows(all_data, temp_df)
}

# --- 4. Processing and Metrics calculation ---

# Extract the App Number
all_data <- all_data %>%
  mutate(App_Num = str_extract(App, "^[0-9]+"))

# Convert columns to number format just in case
all_data$IPC <- as.numeric(as.character(all_data$IPC))
all_data$sim_Is <- as.numeric(as.character(all_data$Sim_Is))
all_data$total_cond_predicts <- as.numeric(as.character(all_data$total_cond_predicts))
all_data$wrong_cond_predicts <- as.numeric(as.character(all_data$wrong_cond_predicts))

# Gets MPKI (Mispredictions Per Kilo Instruction)
all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / sim_Is) * 1000)

# Gets the Conditional Missprediction rate
all_data <- all_data %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

# Verify that the existing metric exists
if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("The metric", opt$metric, "doesn't exist in the data. Available:", paste(colnames(all_data), collapse=", ")))
}

# --- 5. Filtering in accordance to the requested data in the arguments ---

# Filter Configs
if (opt$cores != "ALL") {
  target_cores <- unlist(str_split(opt$cores, ","))
  all_data <- all_data %>% filter(Core %in% target_cores)
}

# Filter Predictors
if (opt$predictors != "ALL") {
  target_preds <- unlist(str_split(opt$predictors, ","))
  all_data <- all_data %>% filter(Predictor %in% target_preds)
}

# Filter Apps
if (!is.null(opt$apps)) {
  target_apps <- unlist(str_split(opt$apps, ","))
  all_data <- all_data %>% filter(App_Num %in% target_apps)
}

if (nrow(all_data) == 0) {
  stop("Warning: After filtering, there is no data left to plot...")
}

# --- 6. Age (Promediar Benchmarks) ---

if (is.null(opt$apps)) {
  # Agrupamos por Core y Predictor y calculamos la media (Geométrica para ratios, Aritmética para conteos)
  summary_data <- all_data %>%
    group_by(Core, Predictor) %>%
    summarise(
      Metric_Value = if(opt$metric %in% c("IPC", "MPKI", "CondMissRate")) geomean(get(opt$metric)) else mean(get(opt$metric)),
      .groups = 'drop'
    ) %>%
    mutate(Config_Label = paste(Core, Predictor, sep="\n"))
} else {
  # Agrupamos por Core, Predictor y App
  summary_data <- all_data %>%
    group_by(Core, Predictor, App) %>%
    summarise(
      Metric_Value = get(opt$metric),
      .groups = 'drop'
    ) %>%
    mutate(Config_Label = paste(Core, Predictor, App, sep="\n"))
}

# --- 7. Generate graph ---
# TODO: Guardar gráfica como imagen vectorial para poder hacer todo el zoom que se quiera

p <- ggplot(summary_data, aes(x = Config_Label, y = Metric_Value, fill = Core)) +
  geom_bar(stat = "identity", position = position_dodge(), width = 0.7, color="black") +
  theme_minimal(base_size = 14) +
  labs(
    title = paste("Comparisson of ", opt$metric),
    subtitle = paste("Mean (Geomean) over SPEC17 benchmarks"),
    x = "Configuration",
    y = opt$metric,
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "top"
  )

# --- 8. Guardar ---
ggsave(opt$output, plot = p, width = 30, height = 12)
cat(paste("Graph succesfully stored in:", opt$output, "\n"))