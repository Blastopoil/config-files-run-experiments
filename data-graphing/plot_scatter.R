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
  
  make_option(c("-c", "--configs"), type="character", default="ALL",
              help="List of Core Configs to include [default %default]", metavar="LIST"),
  
  make_option(c("-p", "--predictors"), type="character", default="ALL",
              help="List of Predictors to include [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Optional list of SPEC app numbers to filter.", metavar="LIST"),
  
  make_option(c("-M", "--model"), type="character", default="linear",
              help="Regression type: 'linear', 'inverse' (1/x), 'log', or 'loess' (smooth) [default %default]", metavar="STR"),

  make_option(c("-A", "--avg_fit"), action="store_true", default=FALSE,
              help="Si se activa, la regresión se calcula sobre el punto medio de cada predictor en lugar de todos los puntos [default %default]")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
files <- list.files(
    path = opt$input, 
    pattern = "*_simple_data.csv", 
    full.names = TRUE
)

if(length(files) == 0) stop("No .csv files found.")

all_data <- data.frame()

for (file in files) { 
    temp_data <- read.csv(
      file,
      stringsAsFactors = FALSE,
      na.strings = c("N/A")
    )

    # Excluye filas que tengan NA en cualquier columna (incluye las que venían como "N/A")
    temp_data <- temp_data[complete.cases(temp_data), ]

    temp_data$config <- str_remove(basename(file), "_simple_data.csv")
    all_data <- rbind(all_data, temp_data)
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
  mutate(MPKI_spec = (branch_mispredicts_at_execute / Sim_Is) * 1000) %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

if (!(opt$x_metric %in% colnames(all_data)) | !(opt$y_metric %in% colnames(all_data))) {
  stop("Metric not found in data.")
}

# --- 4. Filtering ---

# Filters the core configs
# Filters the core configs
if (!is.null(opt$configs) && nzchar(opt$configs) && opt$configs != "ALL") {
  configs_filter <- trimws(strsplit(opt$configs, ",")[[1]])
  all_data <- all_data[all_data$config %in% configs_filter, ]
}

# Filters the Branch Predictors
if (!is.null(opt$predictors) && nzchar(opt$predictors) && opt$predictors != "ALL") {
  predictors_filter <- trimws(strsplit(opt$predictors, ",")[[1]])
  all_data <- all_data[all_data$cond_bp %in% predictors_filter, ]
}

# Filters the SPEC17 apps
all_data <- all_data %>%
  mutate(App = str_remove(App, "_r$"))

apps_to_filter <- NULL
aux_apps <- opt$apps
if (!is.null(opt$apps)) {
  if (opt$apps == "int") {
    aux_apps <- c("500,502,505,520,523,525,531,541,548,557")
  } else if (opt$apps == "float") {
    aux_apps <- c("503,507,508,510,511,519,521,526,527,538,544,549,554")
  } else if (opt$apps == "normal") {
    aux_apps <- c("507,508,510,519,521,526,544,548,549,557")
  } else if (opt$apps == "all") {
    aux_apps <- c("500,502,503,505,507,508,510,511,519,520,521,523,525,526,527,531,538,541,544,548,549,554,557")
  }
} else {
  aux_apps <- c("500,502,503,505,507,508,510,511,519,520,521,523,525,526,527,531,538,541,544,548,549,554,557")
}
apps_to_filter <- trimws(strsplit(aux_apps, ",")[[1]])
spec17_app_map <- c(
  "500" = "500.perlbench", "502" = "502.gcc", "503" = "503.bwaves", "505" = "505.mcf", 
  "507" = "507.cactuBSSN", "508" = "508.namd", "510" = "510.parest", "511" = "511.povray", 
  "519" = "519.lbm", "520" = "520.omnetpp", "521" = "521.wrf", "523" = "523.xalancbmk", 
  "525" = "525.x264", "526" = "526.blender", "527" = "527.cam4", "531" = "531.deepsjeng",
  "538" = "538.imagick", "541" = "541.leela", "544" = "544.nab", "548" = "548.exchange2", 
  "549" = "549.fotonik3d", "554" = "554.roms", "557" = "557.xz"
)
# Converts to full app name
apps_to_filter <- ifelse(
  apps_to_filter %in% names(spec17_app_map),
  unname(spec17_app_map[apps_to_filter]),
  apps_to_filter
)
# Makes the actual filtering
all_data <- all_data[all_data$App %in% apps_to_filter, ]

# --- 5. Generate Scatter Plot ---

get_metric_scale <- function(metric_name, is_x_axis = FALSE) {
  if (metric_name == "IPC") {
    if (is_x_axis) {
      scale_x_continuous(limits = c(0, 4.5), breaks = seq(0, 4.5, by = 1), minor_breaks = seq(0, 4.5, by = 0.5), expand = expansion(mult = c(0, 0.05)))
    } else {
      scale_y_continuous(limits = c(0, 4.5), breaks = seq(0, 4.5, by = 1), minor_breaks = seq(0, 4.5, by = 0.5), expand = expansion(mult = c(0, 0.05)))
    }
  } else if (metric_name == "MPKI" || metric_name == "MPKI_spec") {
    if (is_x_axis) {
      scale_x_continuous(limits = c(0, 150), breaks = seq(0, 150, by = 50), minor_breaks = seq(0, 150, by = 25), expand = expansion(mult = c(0, 0.05)))
    } else {
      scale_y_continuous(limits = c(0, 150), breaks = seq(0, 150, by = 50), minor_breaks = seq(0, 150, by = 25), expand = expansion(mult = c(0, 0.05)))
    }
  } else if (metric_name == "CondMissRate") {
    if (is_x_axis) {
      scale_x_continuous(limits = c(0, 60), breaks = seq(0, 60, by = 20), minor_breaks = seq(0, 60, by = 10), expand = expansion(mult = c(0, 0.05)))
    } else {
      scale_y_continuous(limits = c(0, 60), breaks = seq(0, 60, by = 20), minor_breaks = seq(0, 60, by = 10), expand = expansion(mult = c(0, 0.05)))
    }
  } else {
    NULL
  }
}

p <- ggplot(all_data, aes(x = .data[[opt$x_metric]], 
                          y = .data[[opt$y_metric]], 
                          color = cond_bp,     # Corregido
                          shape = cond_bp)) +  # Corregido
  # Points
  geom_point(size = 3, alpha = 0.7) +
  # Faceting by Core
  facet_wrap(~config, scales = "free") +       # Corregido
  theme_bw(base_size = 14)

# --- REGRESSION LOGIC ---

# Si el usuario pide la regresión por promedios, preparamos los datos
if (opt$avg_fit) {
  # 1. Calculamos el promedio de X e Y para cada predictor y configuración
  avg_data <- all_data %>%
    group_by(config, cond_bp) %>%
    summarise(
      x_metric_val = mean(.data[[opt$x_metric]], na.rm = TRUE),
      y_metric_val = mean(.data[[opt$y_metric]], na.rm = TRUE),
      .groups = "drop"
    )
  
  # 2. Renombramos las columnas calculadas para que ggplot las entienda correctamente
  names(avg_data)[names(avg_data) == "x_metric_val"] <- opt$x_metric
  names(avg_data)[names(avg_data) == "y_metric_val"] <- opt$y_metric
  
  # 3. Dibujamos los puntos promedio para que se vea de dónde sale la regresión
  p <- p + geom_point(data = avg_data, size = 5, shape = 21, stroke = 1.2, color = "black", aes(fill = cond_bp))
}

# Función auxiliar para aplicar la línea correcta sin repetir código
apply_smooth <- function(plot_obj, method_type, formula_type) {
  if (opt$avg_fit) {
    # Al poner aes(group = 1), fuerza a ggplot a dibujar 1 sola línea ignorando los colores (predictores)
    plot_obj + geom_smooth(data = avg_data, mapping = aes(group = 1), color = "black", method = method_type, formula = formula_type, se = FALSE, linewidth = 1.2)
  } else {
    # Comportamiento original (múltiples líneas)
    plot_obj + geom_smooth(method = method_type, formula = formula_type, se = FALSE, linewidth = 1.2)
  }
}

if (opt$model == "linear") {
  p <- apply_smooth(p, "lm", y ~ x)
  model_title <- "Linear Fit"

} else if (opt$model == "inverse") {
  p <- apply_smooth(p, "lm", y ~ I(1/x))
  model_title <- "Inverse Fit (1/x)"

} else if (opt$model == "log") {
  p <- apply_smooth(p, "lm", y ~ log(x))
  model_title <- "Logarithmic Fit"

} else if (opt$model == "loess") {
  p <- apply_smooth(p, "loess", y ~ x)
  model_title <- "Loess Smooth"
}

# Labels and Theme
p <- p + labs(
    title = paste("Correlation:", opt$y_metric, "vs", opt$x_metric),
    subtitle = paste("Model:", model_title, "| Each point is a SPEC Benchmark belonging to the ", opt$apps, " suite"),
    x = opt$x_metric,
    y = opt$y_metric
  ) +
  theme(
    axis.text = element_text(size = 12),
    legend.position = "top",
    strip.text = element_text(face = "bold", size = 14)
  )

# Scales
p <- p + get_metric_scale(opt$x_metric, is_x_axis = TRUE) +
         get_metric_scale(opt$y_metric, is_x_axis = FALSE)

# --- 6. Save ---
ggsave(opt$output, plot = p, width = 10, height = 8)
cat(paste("Scatter plot saved:", opt$output, "\n"))

system(paste("xdg-open", opt$output))