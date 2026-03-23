#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ggplot2)
  library(ggthemes)
  library(paletteer)
  library(dplyr)
  library(glue)
  library(svglite)
})

# --- 1. Arguments ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Input folder [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filters specific SPEC17 rate apps (none if not passed).\n\t\t'int' uses all SPEC17int apps\n\t\t'float' the SPEC17float apps\n\t\t'normal' a custom set of apps", metavar="LIST")
              
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
file <- list.files(path = opt$input, pattern = "delay_experiments_data.csv", full.names = TRUE)
if(length(file) == 0) stop("No .csv file was found")

all_data <- data.frame()

all_data <- read.csv(file, na.strings = c("NA", "NaN", "nan", "NAN", ""))

# --- 3. Data Processing ---
# Filters data acording to the passed arguments

# Filters the Branch Predictors
if (!is.null(opt$predictors) && nzchar(opt$predictors)) {
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

# Adds columns

all_data <- all_data %>%
  mutate(
    across(c(Sim_Is, total_cond_predicts, wrong_cond_predicts), ~ suppressWarnings(as.numeric(.x))),
    MPKI = ifelse(is.finite(wrong_cond_predicts / Sim_Is), 1000 * wrong_cond_predicts / Sim_Is, NA_real_),
    CondMissRate = ifelse(is.finite(wrong_cond_predicts / total_cond_predicts), 100 * wrong_cond_predicts / total_cond_predicts, NA_real_)
  )

if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

print(all_data)

# --- 4. Graph Creation ---

# For the title of the plots' creation/s
if (!is.null(opt$apps)) {
  if (opt$apps == "int") {
    apps_studied <- "(Integer) 500,502,505,520,523,525,531,541,548,557"
  } else if (opt$apps == "float") {
    apps_studied <- "(Floating Point) 503,507,508,510,511,519,521,526,527,538,544,549,554"
  } else if (opt$apps == "normal") {
    apps_studied <- "507,508,510,519,521,526,544,548,549,557"
  } else {
    apps_studied <- paste(apps_to_filter, collapse=", ")
  }
}

get_scale <- function() {
  if (opt$metric == "IPC") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(0, 1),
                      breaks = seq(0, 1, by = 0.2), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 1, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "MPKI") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(0, 2),
                      breaks = seq(0, 2, by = 0.2),
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "CondMissRate") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(0, 2),
                      breaks = seq(0, 2, by = 0.2), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  }
}
get_average_function <- function() {
    if (opt$metric == "IPC") {
        function(x) {
          x <- suppressWarnings(as.numeric(x))
          x <- x[is.finite(x) & x > 0]
          if (length(x) == 0) return(NA_real_)
          exp(mean(log(x)))
        }
    } else if (opt$metric == "MPKI") {
        mean
    } else if (opt$metric == "CondMissRate") {
        mean
    } else {
        stop(paste("Metric not found:", opt$metric))
    }
}
  
# Label to filter by config and conditional branch predictor
all_data <- all_data %>%
  mutate(
    delay_label = as.character(general_delay),
    config_label = paste(cond_bp, sep = "\n")
  )

# Keep delay order numeric when possible
delay_vals <- unique(all_data$delay_label)
delay_num <- suppressWarnings(as.numeric(delay_vals))
if (all(!is.na(delay_num))) {
  delay_levels <- delay_vals[order(delay_num)]
} else {
  delay_levels <- sort(delay_vals)
}

# Optional: aggregate in case there are repeated rows for same app+delay
all_data_lines <- all_data %>%
  mutate(delay_order = match(delay_label, delay_levels)) %>%
  group_by(App, delay_label, delay_order) %>%
  summarise(
    raw_value = get_average_function()(.data[[opt$metric]]),
    .groups = "drop"
  ) %>%
  arrange(App, delay_order) %>%
  group_by(App) %>%
  mutate(value = raw_value / first(raw_value)) %>%
  ungroup()

# The title and subtitle for the plot
if (is.null(opt$apps)) {
  my_title = glue("Relation between {opt$metric} and delay using {opt$predictors}")
  my_subtitle = NULL
} else {
  my_title = glue("Relation between {opt$metric} and delay with {opt$predictors} using these SPEC17 apps:")
  my_subtitle = glue("{apps_studied}")
}

ggplot(
  all_data_lines,
  aes(
    x = factor(delay_label, levels = delay_levels),
    y = value,
    color = App,
    group = App
  )
) +
geom_line(size = 1) +
geom_point(size = 3) +
labs(title = my_title, subtitle = my_subtitle, y = opt$metric, x = "Delay", color = "App") +
theme_bw() + 
theme(
  text = element_text(family = "sans", size = 18),
  panel.grid.major = element_line(color = "grey90"),
  panel.grid.minor = element_blank(),
  plot.title = element_text(size = 18, face = "bold", margin = margin(b = 10), hjust = 0.5),
  plot.subtitle = element_text(size = 16, face = "bold", hjust = 0.5),
  axis.text.x = element_text(size = 14, angle = 45, hjust = 1),
  axis.title.x = element_text(margin = margin(t = 10)),
  legend.position = "top"
) +
get_scale()


ggsave(opt$output, width=10, height=6)
system(paste("xdg-open", opt$output))