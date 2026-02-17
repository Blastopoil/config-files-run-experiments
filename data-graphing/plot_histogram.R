#!/usr/bin/env Rscript

# ==============================================================================
# SCRIPT DE GENERACIÓN DE GRÁFICOS (MODO BATCH INCLUIDO)
#
# 1. Modo Normal (Media Geométrica de todo):
#    Rscript plot_histogram.R -m IPC -o salida.png
#
# 2. Modo Batch (Generar una gráfica por cada App automáticamente):
#    Rscript data-graphing/plot_histogram.R -m MPKI -c BigO3,SmallO3 -p AlwaysTrueBP,LocalBP,TAGE_SC_L --batch -o todas_histograms_mpkis/graf.png
#    -> Esto creará carpeta_salida/graf_502.png, carpeta_salida/graf_505.png, etc.
# ==============================================================================

suppressPackageStartupMessages({
  library(optparse)
  library(ggplot2)
  library(ggpattern)
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
})

# --- 1. Argumentos ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Carpeta de entrada [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-c", "--cores"), type="character", default="ALL",
              help="Cores (ej: 'BigO3,SmallO3') [default %default]", metavar="LIST"),
  
  make_option(c("-p", "--predictors"), type="character", default="ALL",
              help="Predictores (ej: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filtrar apps específicas (opcional incluso en batch) [default NULL]", metavar="LIST"),

  make_option(c("--patterns"), action="store_true", default=FALSE,
              help="Usar patrones monocromáticos (requiere ggpattern)"),
  
  # NUEVO ARGUMENTO: MODO BATCH
  make_option(c("-B", "--batch"), action="store_true", default=FALSE,
              help="Si se activa, genera una gráfica individual por cada App encontrada automáticamente.")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Funciones Auxiliares ---

geomean <- function(x) {
  x_clean <- as.numeric(x)
  x_clean <- x_clean[x_clean > 0 & !is.na(x_clean)]
  if(length(x_clean) == 0) return(0)
  exp(mean(log(x_clean)))
}

# Función para generar el objeto gráfico (para reutilizar código)
create_plot_object <- function(data, metric_name, title_suffix, use_patterns) {
  
  # Ordenar eje X para estética
  data$Config_Label <- factor(data$Config_Label, levels = unique(data$Config_Label))
  
  if (use_patterns && require("ggpattern", quietly = TRUE)) {
    # Lógica con Patrones (si la librería carga)
    p <- ggplot(data, aes(x = Config_Label, y = Metric_Value, pattern = Core, fill = Core)) +
      geom_bar_pattern(stat = "identity", position = position_dodge(), width = 0.7,
                       color = "black", pattern_fill = "white", pattern_density = 0.15) +
      scale_pattern_manual(values = c("stripe", "crosshatch", "circle", "wave", "weave", "diagonal", "grid")) +
      scale_fill_grey() +
      theme_minimal(base_size = 14)
  } else {
    # Lógica con Colores (Estándar)
    p <- ggplot(data, aes(x = Config_Label, y = Metric_Value, fill = Core)) +
      geom_bar(stat = "identity", position = position_dodge(), width = 0.7, color = "black") +
      theme_minimal(base_size = 14)
  }
  
  p <- p +
    labs(
      title = paste("Comparison of", metric_name),
      subtitle = title_suffix,
      x = "Configuration",
      y = metric_name
    ) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 18), # Ajustado tamaño para que quepa
      axis.text.y = element_text(size = 18),
      axis.title = element_text(size = 20),
      legend.text = element_text(size = 16),
      legend.title = element_text(size = 18),
      plot.title = element_text(size = 24, face="bold"),
      plot.subtitle = element_text(size = 18),
      legend.position = "top"
    )
  return(p)
}

# --- 3. Carga de Datos ---

files <- list.files(path = opt$input, pattern = "*.csv", full.names = TRUE)
if(length(files) == 0) stop("No se encontraron archivos .csv.")

all_data <- data.frame()

for (f in files) { 
  fname <- basename(f)
  clean_name <- str_remove(str_remove(fname, "tagescl_data_"), ".csv")
  parts <- str_split(clean_name, "_", n = 2)[[1]]
  
  # Leer como caracter para evitar problemas de tipos
  temp_df <- read_csv(f, col_types = cols(.default = "c"), show_col_types = FALSE)
  
  temp_df$Core <- parts[1]
  temp_df$Predictor <- parts[2]
  all_data <- bind_rows(all_data, temp_df)
}

# --- 4. Procesamiento ---

all_data <- all_data %>% mutate(App_Num = str_extract(App, "^[0-9]+"))

# Conversión numérica segura
suppressWarnings({
  all_data$IPC <- as.numeric(all_data$IPC)
  all_data$Sim_Is <- as.numeric(all_data$Sim_Is)
  all_data$total_cond_predicts <- as.numeric(all_data$total_cond_predicts)
  all_data$wrong_cond_predicts <- as.numeric(all_data$wrong_cond_predicts)
})

# Cálculo de métricas
all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

# --- 5. Filtrado Global ---

if (opt$cores != "ALL") {
  all_data <- all_data %>% filter(Core %in% unlist(str_split(opt$cores, ",")))
}
if (opt$predictors != "ALL") {
  all_data <- all_data %>% filter(Predictor %in% unlist(str_split(opt$predictors, ",")))
}
# Si el usuario especificó apps con -a, filtramos también (útil para el batch mode si solo quieres unas pocas)
if (!is.null(opt$apps)) {
  target_apps <- unlist(str_split(opt$apps, ","))
  all_data <- all_data %>% filter(App_Num %in% target_apps)
}

if (nrow(all_data) == 0) stop("No hay datos tras el filtrado.")

# --- 6. Generación de Gráficas (LÓGICA PRINCIPAL) ---

# Preparamos el directorio de salida si no existe
output_dir <- dirname(opt$output)
if (!dir.exists(output_dir) && output_dir != ".") {
  dir.create(output_dir, recursive = TRUE)
}
file_base <- tools::file_path_sans_ext(basename(opt$output))
file_ext <- tools::file_ext(opt$output)


if (opt$batch) {
  # === MODO BATCH: ITERAR SOBRE APPS ===
  
  unique_apps <- unique(all_data$App_Num)
  cat(paste("Modo Batch activado. Se generarán", length(unique_apps), "gráficas.\n"))
  
  for (app_id in unique_apps) {
    # 1. Filtrar solo esta app
    app_data <- all_data %>% filter(App_Num == app_id)
    
    # 2. Preparar datos (Sin medias, dato crudo)
    plot_data <- app_data %>%
      mutate(Metric_Value = get(opt$metric)) %>%
      mutate(Config_Label = paste(Core, Predictor, sep="\n"))
    
    # 3. Crear gráfica
    p <- create_plot_object(plot_data, opt$metric, paste("Benchmark:", app_id), opt$patterns)
    
    # 4. Guardar con sufijo
    new_filename <- file.path(output_dir, paste0(file_base, "_", app_id, ".", file_ext))
    
    ggsave(new_filename, plot = p, width = 20, height = 10) # Ajustado tamaño
    cat(paste("  -> Guardado:", new_filename, "\n"))
  }
  
} else {
  # === MODO ESTÁNDAR: MEDIA GEOMÉTRICA (o lo que fuera antes) ===
  
  # Si el usuario no pasó apps específicas y NO está en batch -> Geomean
  if (is.null(opt$apps)) {
    plot_data <- all_data %>%
      group_by(Core, Predictor) %>%
      summarise(
        Metric_Value = if(opt$metric %in% c("IPC", "MPKI", "CondMissRate")) geomean(get(opt$metric)) else mean(get(opt$metric)),
        .groups = 'drop'
      ) %>%
      mutate(Config_Label = paste(Core, Predictor, sep="\n"))
    subtitle_txt <- "Geomean (SPEC17)"
  } else {
    # Si pasó apps específicas pero NO batch, las pinta todas juntas (como en tu script original)
    plot_data <- all_data %>%
      mutate(Metric_Value = get(opt$metric)) %>%
      mutate(Config_Label = paste(Core, Predictor, App, sep="\n"))
    subtitle_txt <- paste("Apps:", opt$apps)
  }
  
  p <- create_plot_object(plot_data, opt$metric, subtitle_txt, opt$patterns)
  ggsave(opt$output, plot = p, width = 20, height = 10)
  cat(paste("Gráfica guardada en:", opt$output, "\n"))
}