#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ggplot2)
  library(ggthemes)
  library(paletteer)
  library(dplyr)
  library(tidyr) # NUEVO: Necesario para pivot_wider() y calcular el Delta IPC
  library(glue)
  library(svglite)
})

# --- 1. Arguments ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Carpeta de entrada [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate, CondBranches) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-c", "--configs"), type="character", default=NULL,
            help="Filter core configs (ex: 'BigO3,SmallO3') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filters specific SPEC17 rate apps (none if not passed).\n\t\t'int' uses all SPEC17int apps\n\t\t'float' the SPEC17float apps\n\t\t'normal' a custom set of apps", metavar="LIST"),

  make_option(c("-v", "--various"), type="character", default="one",
              help="'two' for studying the experiemnt in which 2 apps executed in Full System")
            
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
files <- list.files(
    path = opt$input, 
    pattern = "*_simple_data.csv", 
    full.names = TRUE
)

if(length(files) == 0) stop("No .csv file was found")

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

# --- 3. Data Processing ---

# Filters the Branch Predictors
if (!is.null(opt$predictors) && nzchar(opt$predictors)) {
  predictors_filter <- trimws(strsplit(opt$predictors, ",")[[1]])
  all_data <- all_data[all_data$cond_bp %in% predictors_filter, ]
}

# Filters the core configs
if (!is.null(opt$configs) && nzchar(opt$configs)) {
  configs_filter <- trimws(strsplit(opt$configs, ",")[[1]])
  all_data <- all_data[all_data$config %in% configs_filter, ]
}

# Filters the SPEC17 apps
if (opt$various == "one") {
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
  apps_to_filter <- ifelse(
    apps_to_filter %in% names(spec17_app_map),
    unname(spec17_app_map[apps_to_filter]),
    apps_to_filter
  )
  all_data <- all_data[all_data$App %in% apps_to_filter, ]
} else {
  all_data <- all_data %>%
    mutate(App = str_remove(App, "_r$"))
}

# Adds columns
all_data <- all_data %>%
  mutate(MPKI_spec = (branch_mispredicts_at_execute / Sim_Is) * 1000) %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100) %>%
  mutate(CondBranches = total_cond_predicts)

if (!(opt$metric %in% colnames(all_data)) && opt$mode != "sensitivity") {
  stop(paste("Métrica no encontrada:", opt$metric))
}

# --- 4. Graph Creation ---

get_limit <- function(mode, limit) { if (mode == "mean" ) { limit } else { NULL } }
get_breaks <- function(mode, breaks) { if (mode == "mean" || mode == "series") { breaks } else { NULL } }
get_scale <- function(mode) {
  if (mode == "batch") { return(NULL) }
}
get_average_function <- function() {
    if (opt$metric == "IPC") { function(x) exp(mean(log(x)))
    } else if (opt$metric %in% c("MPKI", "MPKI_spec", "CondMissRate", "CondBranches")) { mean
    } else { stop(paste("Metric not found:", opt$metric)) }
}
  
base_pred <- "LocalBP"
adv_pred <- "TAGE_SC_L_64"

if (!is.null(opt$predictors)) {
  preds <- trimws(strsplit(opt$predictors, ",")[[1]])
  if (length(preds) >= 2) {
    base_pred <- preds[1]
    adv_pred <- preds[2]
  }
}

metrica <- opt$metric
columnas_pivot <- unique(c(metrica, "MPKI")) 

df_sens <- all_data %>%
  filter(cond_bp %in% c(base_pred, adv_pred)) %>%
  select(App, config, cond_bp, all_of(columnas_pivot)) %>%
  pivot_wider(names_from = cond_bp, values_from = all_of(columnas_pivot))

col_metric_base <- paste0(metrica, "_", base_pred)
col_metric_adv  <- paste0(metrica, "_", adv_pred)
col_mpki_base   <- paste0("MPKI_", base_pred)

if (!(col_metric_base %in% colnames(df_sens)) || !(col_metric_adv %in% colnames(df_sens))) {
  stop(glue("No se pudieron pivotar las columnas. Asegúrate de que la métrica '{metrica}' es correcta y los predictores existen en los datos."))
}

umbral_mpki <- 10
umbral_y <- if (metrica == "IPC") 20 else 5 

df_sens <- df_sens %>%
  mutate(
    Delta_Y = if (metrica == "IPC") {
      ((.data[[col_metric_adv]] - .data[[col_metric_base]]) / .data[[col_metric_base]]) * 100
    } else {
      .data[[col_metric_adv]] - .data[[col_metric_base]]
    },
    Base_MPKI = .data[[col_mpki_base]]
  ) %>%
  filter(!is.na(Delta_Y) & !is.na(Base_MPKI)) %>%
  mutate(
    Categoria = case_when(
      Base_MPKI < umbral_mpki  & abs(Delta_Y) < umbral_y   ~ as.character(glue("Bajo MPKI, bajo cambio de {metrica}")),
      Base_MPKI < umbral_mpki  & abs(Delta_Y) >= umbral_y  ~ as.character(glue("Bajo MPKI, alto cambio de {metrica}")),
      Base_MPKI >= umbral_mpki & abs(Delta_Y) < umbral_y   ~ as.character(glue("Alto MPKI, bajo cambio de {metrica}")),
      Base_MPKI >= umbral_mpki & abs(Delta_Y) >= umbral_y  ~ as.character(glue("Alto MPKI, alto cambio de {metrica}"))
    )
  )

if (metrica == "CondMissRate") {
  umbral_y <- -5
}

my_title <- glue("Sensibilidad al Predictor: {base_pred} vs {adv_pred} ({metrica})")
my_subtitle <- glue("Relación entre la intensidad de fallos base y el cambio de {metrica}")

# Forzamos un factor para mantener siempre el mismo orden en la leyenda de la gráfica
niveles_categoria <- c(
  as.character(glue("Bajo MPKI, bajo cambio de {metrica}")),
  as.character(glue("Bajo MPKI, alto cambio de {metrica}")),
  as.character(glue("Alto MPKI, bajo cambio de {metrica}")),
  as.character(glue("Alto MPKI, alto cambio de {metrica}"))
)
df_sens$Categoria <- factor(df_sens$Categoria, levels = niveles_categoria)

# Paleta de colores mapeada a los niveles exactos
colores_cuadrantes <- setNames(
  c("#5DADE2", "#F5B041", "#E74C3C", "#27AE60"),
  niveles_categoria
)

# Etiqueta dinámica del eje Y
y_label <- if (metrica == "IPC") {
  glue("Incremento de IPC (%) con {adv_pred}")
} else {
  glue("Delta de {metrica} con {adv_pred} (Puntos)")
}

p <- ggplot(df_sens, aes(x = Base_MPKI, y = Delta_Y, color = Categoria)) +
  # Línea vertical del MPKI
  geom_vline(xintercept = umbral_mpki, linetype = "dotted", color = "gray50", linewidth = 0.8) +
  geom_hline(yintercept = umbral_y, linetype = "dotted", color = "gray50", linewidth = 0.8) +
  # Puntos y textos
  geom_point(size = 4, alpha = 0.9) +
  geom_text(aes(label = str_remove(App, "^\\d+\\.")), 
            vjust = -0.8, hjust = 0.5, size = 4, show.legend = FALSE, check_overlap = TRUE) +
  # Línea de tendencia global
  geom_smooth(aes(x = Base_MPKI, y = Delta_Y), method = "lm", se = FALSE, 
              linetype = "dashed", color = "gray40", inherit.aes = FALSE) +
  scale_color_manual(values = colores_cuadrantes, drop = FALSE) +
  labs(
    title = my_title,
    subtitle = my_subtitle,
    x = glue("Intensidad de fallos ({base_pred} MPKI)"),
    y = y_label,
    color = "Clasificación"
  ) +
  theme_bw() +
  theme(
    text = element_text(family = "sans", size = 16),
    plot.title = element_text(size = 18, face = "bold", hjust = 0.5, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 14, hjust = 0.5, margin = margin(b = 20)),
    panel.grid.major = element_line(color = "grey85"),
    panel.grid.minor = element_blank(),
    legend.position = "none"
  )

print(p)
ggsave(opt$output, width = 13, height = 8)

args_pasados <- commandArgs(trailingOnly = TRUE)
comando_ejecutado <- paste("Rscript data-graphing/plot_sensitivity.R", paste(args_pasados, collapse = " "))
system(sprintf("exiftool -q -overwrite_original -Comment='%s' %s", comando_ejecutado, opt$output))
system(paste("xdg-open", opt$output))