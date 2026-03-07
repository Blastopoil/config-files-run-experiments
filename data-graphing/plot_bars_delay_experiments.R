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
  
  make_option(c("-o", "--output"), type="character", default="grafico.svg",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filters specific SPEC17 rate apps (none if not passed).\n\t\t'int' uses all SPEC17int apps\n\t\t'float' the SPEC17float apps\n\t\t'normal' a custom set of apps", metavar="LIST"),
  
  make_option(c("-M", "--mode"), type="character", default="mean",
              help="'mean': makes the mean of the data\n\t\t'separate': makes a single plot where each apps results gets its bar\n\t\t'batch': makes a plot for each apps result\n\t\t'series': makes plot with bar per app result and one final bar with mean"),

  make_option(c("-C", "--compare"), type="character", default="bp",
              help="Attention! This argument is only used in 'separate' mode (not activated by default)\n\t\t'bp': groups bars by predictor\n\t\t'config': groups bars by core config\n\t\t'app': groups bars by app")
            
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
file <- list.files(path = opt$input, pattern = "delay_experiments_data.csv", full.names = TRUE)
if(length(file) == 0) stop("No .csv file was found")

all_data <- data.frame()

temp_data <- read.csv(file)
all_data <- rbind(all_data, temp_data)

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
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)


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
                      limits = c(0, 3),
                      breaks = seq(0, 4.5, by = 0.5), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "MPKI") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(-1, 90),
                      breaks = seq(0, 180, by = 10),
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "CondMissRate") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(0, 20),
                      breaks = seq(0, 70, by = 5), 
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
        function(x) exp(mean(log(x)))
    } else if (opt$metric == "MPKI") {
        mean
    } else if (opt$metric == "CondMissRate") {
        mean
    } else {
        stop(paste("Metric not found:", opt$metric))
    }
}

# Creates one plot for all the apps or a set of apps
if (length(apps_to_filter) > 1 || is.null(opt$apps)) {

  # Label to filter by config and conditional branch predictor
  all_data <- all_data %>%
    mutate(group_label = paste(general_delay, cond_bp, sep="\n")) %>%
    mutate(config_label = paste(cond_bp, sep="\n"))
  
  # Calculates mean, sd, se and IC
  my_sum <- all_data %>%
  group_by(general_delay, group_label, config_label, cond_bp) %>%
  summarise( 
      n=n(),
      mean=get_average_function()(.data[[opt$metric]]),
      sd=sd(.data[[opt$metric]]),
      .groups = "drop"
  ) %>%
  mutate( se=sd/sqrt(n))  %>%
  mutate( ic=se * qt((1-0.05)/2 + .5, n-1))

  # The title and subtitle for the plot
  if (is.null(opt$apps)) {
    my_title = glue("Relation between {opt$metric} and delay")
    my_subtitle = NULL
  } else {
    my_title = glue("Relation between {opt$metric} and delay using these SPEC17 apps:")
    my_subtitle = glue("{apps_studied}")
  }

  # The actual figure creation
  ggplot(my_sum, aes(x=group_label, y=mean, fill=config_label)) +
  scale_fill_paletteer_d("nationalparkcolors::Arches") +
  geom_bar(stat="identity", position=position_dodge(width=0.8), 
           width=0.7, 
           # Contorno negro para definir la barra
           color = "black",
           # Grosor del contorno
           linewidth = 0.3,
           # Un poco de transparencia para suavizar el tono)
           #alpha = 0.85
          ) +
  geom_errorbar(aes(ymin=mean-ic, ymax=mean+ic), width=0.2, colour="black", alpha=0.9, linewidth=0.4, position=position_dodge(0.7)) +
  labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="Delay & Branch Predictor") +
  theme_bw() + 
  theme(text = element_text(family = "sans", size = 18),
        # Rejilla principal muy tenue
        panel.grid.major = element_line(color = "grey90"),
        # Elimina rejilla secundaria
        panel.grid.minor = element_blank(),
        plot.title = element_text(size=18, face="bold", margin=margin(b=10), hjust=0.5),
        plot.subtitle = element_text(size=16, face="bold", hjust=0.5),
        #axis.text.x  = element_text(size=14, angle=45, hjust=1),
        axis.title.x = element_text(margin = margin(t = 10)),  # separa el título de las etiquetas
        # Mover la leyenda arriba
        legend.position = "top"
       ) +
  get_scale()
  
  
  ggsave(opt$output, width=10, height=6)
  system(paste("xdg-open", opt$output))


} else {
  print("Something went wrong with the app selection, no graphs generated")
}