#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ggplot2)
  library(ggthemes)
  library(paletteer)
  library(dplyr)
  library(svglite)
  library(glue)
})

# --- 1. Definición de Argumentos ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Archivo CSV de entrada [default %default]", metavar="FILE"),
  
  make_option(c("-o", "--output"), type="character", default="graf_width_series.svg",
              help="Nombre del archivo de salida [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="CondMissRate",
              help="Métrica a visualizar (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors para filtrar separados por coma (ej: 'TAGE_SC_L,LocalBP') [default %default]", metavar="LIST"),
              
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Apps de SPEC17 para filtrar separadas por coma (ej: '502.gcc,505.mcf') [default %default]", metavar="LIST")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Cargar Datos ---
file <- list.files(path = opt$input, pattern = "width_change_data.csv", full.names = TRUE)
if(length(file) == 0) stop("No .csv file was found")

all_data <- data.frame()

temp_data <- read.csv(file)
all_data <- rbind(all_data, temp_data)

# --- 3. Procesamiento y Filtrado de Datos ---

# Limpiamos el nombre de las aplicaciones
all_data <- all_data %>%
  mutate(App = str_remove(App, "_r$"))

# Filtramos por predictores (si se especifica en los argumentos)
if (!is.null(opt$predictors) && nzchar(opt$predictors)) {
  predictors_filter <- trimws(strsplit(opt$predictors, ",")[[1]])
  all_data <- all_data[all_data$cond_bp %in% predictors_filter, ]
}

# Filtramos por apps (si se especifica en los argumentos)
if (!is.null(opt$apps) && nzchar(opt$apps)) {
  apps_filter <- trimws(strsplit(opt$apps, ",")[[1]])
  all_data <- all_data[all_data$App %in% apps_filter, ]
}

# Calculamos las métricas (IPC ya viene en el CSV, calculamos MPKI y CondMissRate)
all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

# Verificamos que la métrica pedida exista
if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

# Creamos la etiqueta de Configuración de Widths
# Formato: FW:X BW:Y CW:Z
all_data <- all_data %>%
  mutate(config = paste0("FW:", frontend_width, " BW:", backend_width, " CW:", commit_width))

# --- 4. Lógica "Series" (Agrupación y Promedios) ---

# Promedio por App
app_sum <- all_data %>%
  group_by(App, config, cond_bp) %>%
  summarise( 
      mean = mean(.data[[opt$metric]], na.rm = TRUE),
      .groups = "drop"
  )

# Promedio Global (Average)
mean_sum <- all_data %>%
  group_by(config, cond_bp) %>%
  summarise( 
      mean = mean(.data[[opt$metric]], na.rm = TRUE),
      .groups = "drop"
  ) %>%
  mutate(App = "Average")

# Unimos ambos
my_sum <- bind_rows(app_sum, mean_sum)

# Aseguramos que "Average" salga al final a la derecha
app_levels <- c(unique(app_sum$App), "Average")
my_sum$App <- factor(my_sum$App, levels = app_levels)

# Etiqueta combinada para la leyenda (Width + Predictor)
my_sum <- my_sum %>%
  mutate(fill_label = paste(config, cond_bp, sep="\n"))

# --- 5. Funciones de Escala Visual ---
get_scale <- function() {
  if (opt$metric == "IPC") {
    scale_y_continuous(limits = c(0, 4.5), breaks = seq(0, 4.5, by = 0.5), 
                       minor_breaks = seq(0, 4, by = 0.1), expand = expansion(mult = c(0, 0.05)))
  } else if (opt$metric == "MPKI") {
    scale_y_continuous(limits = c(-1, 90), breaks = seq(0, 180, by = 10), 
                       minor_breaks = seq(0, 90, by = 5), expand = expansion(mult = c(0, 0.05)))
  } else if (opt$metric == "CondMissRate") {
    scale_y_continuous(limits = c(0, 20), breaks = seq(0, 70, by = 5), 
                       minor_breaks = seq(0, 20, by = 1), expand = expansion(mult = c(0, 0.05)))
  }
}

# --- 6. Creación del Gráfico ---
my_title <- glue("Relation between {opt$metric} and Width configurations per SPEC17 App")
my_subtitle <- "Width format: FW:(Frontend) BW:(Backend) CW:(Commit). Includes overall Average."

ggplot(my_sum, aes(x=App, y=mean, fill=fill_label)) +
  # Usamos una paleta con más colores (Tableau 10) porque hay hasta 8 combinaciones posibles
  scale_fill_paletteer_d("ggthemes::Tableau_10") +
  geom_bar(stat="identity", position=position_dodge(width=0.8), 
           width=0.7, color = "black", linewidth = 0.3) +
  labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="Application", fill="Width + Branch Predictor") +
  theme_bw() + 
  theme(text = element_text(family = "sans", size = 18),
        panel.grid.major = element_line(color = "grey90"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(size=18, face="bold", margin=margin(b=10), hjust=0.5),
        plot.subtitle = element_text(size=16, face="bold", hjust=0.5),
        axis.text.x = element_text(angle=45, hjust=1), 
        axis.title.x = element_text(margin = margin(t = 10)),
        legend.position = "top"
       ) +
  get_scale()

# Guardar y abrir
ggsave(opt$output, width=16, height=7)
system(paste("xdg-open", opt$output))