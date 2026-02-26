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
              help="Carpeta de entrada [default %default]", metavar="DIR"),
  
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
files <- list.files(
    path = opt$input, 
    pattern = "*_simple_data.csv", 
    full.names = TRUE
)

if(length(files) == 0) stop("No .csv file was found")

all_data <- data.frame()

for (file in files) { 
    temp_data <- read.csv(file, stringsAsFactors = FALSE)
    temp_data$config <- str_remove(basename(file), "_simple_data.csv")
    all_data <- rbind(all_data, temp_data)
}

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

# For the scale
get_limit <- function(mode, limit) {
  if (mode == "mean" ) {
    limit
  } else {
    NULL
  }
}
get_breaks <- function(mode, breaks) {
  if (mode == "mean" || mode == "series") {
    breaks
  } else {
    NULL
  }
}
get_scale <- function(mode) {
  if (mode == "batch") {
    NULL
  } else if (opt$metric == "IPC") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = get_limit(opt$mode, c(0, 4.5)),
                      breaks = get_breaks(opt$mode, seq(0, 4.5, by = 0.5)), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "MPKI") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = get_limit(opt$mode, c(-1, 90)),
                      breaks = get_breaks(opt$mode, seq(0, 180, by = 10)),
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "CondMissRate") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = get_limit(opt$mode, c(0, 35)),
                      breaks = get_breaks(opt$mode, seq(0, 70, by = 5)), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  }
}

# Creates one plot for all the apps or a set of apps
if (opt$mode == "mean" && (length(apps_to_filter) > 1 || is.null(opt$apps))) {

  # Label to filter by config and conditional branch predictor
  all_data <- all_data %>%
    mutate(group_label = paste(config, cond_bp, sep="\n"))
  
  # Calculates mean, sd, se and IC
  my_sum <- all_data %>%
  group_by(group_label, config, cond_bp) %>%
  summarise( 
      n=n(),
      mean=mean(.data[[opt$metric]]),
      sd=sd(.data[[opt$metric]]),
      .groups = "drop"
  ) %>%
  mutate( se=sd/sqrt(n))  %>%
  mutate( ic=se * qt((1-0.05)/2 + .5, n-1))

  # The title and subtitle for the plot
  if (is.null(opt$apps)) {
    my_title = glue("Relation between {opt$metric} and the following configurations")
    my_subtitle = NULL
  } else {
    my_title = glue("Relation between {opt$metric} and configurations using these SPEC17 apps:")
    my_subtitle = glue("{apps_studied}")
  }

  # The actual figure creation
  ggplot(my_sum, aes(x=group_label, y=mean, fill=config)) +
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
  labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="Core + Branch Predictor") +
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
  get_scale(opt$mode)
  
  
  ggsave(opt$output, width=10, height=6)
  #system(paste("xdg-open", opt$output))


} else if (opt$mode == "separate" && (length(apps_to_filter) > 1 || is.null(opt$apps))) {

  # Determina qué usar para agrupar visualmente según --compare
  if (opt$compare == "bp") {
    # Agrupa por predictor: X = config+app, fill = bp
    all_data <- all_data %>%
      mutate(group_label = paste(config, App, sep="\n"))
    fill_var <- "cond_bp"
  } else if (opt$compare == "config") {
    # Agrupa por config: X = bp+app, fill = config
    all_data <- all_data %>%
      mutate(group_label = paste(cond_bp, App, sep="\n"))
    fill_var <- "config"
  } else if (opt$compare == "app") {
    # Agrupa por app: X = config+bp, fill = app
    all_data <- all_data %>%
      mutate(group_label = paste(config, cond_bp, sep="\n"))
    fill_var <- "App"
  } else {
    stop("Invalid --compare option. Use 'bp', 'config', or 'app'")
  }

  # Calcula media manteniendo todas las dimensiones
  my_sum <- all_data %>%
  group_by(group_label, config, cond_bp, App) %>%
  summarise( 
      n=n(),
      mean=mean(.data[[opt$metric]]),
      .groups = "drop"
  )

  # The title for the plot
  apps_studied <- paste(apps_to_filter, collapse=", ")
  my_title = glue("Relation between {opt$metric} and configurations using these SPEC17 apps: {apps_studied}\nFocuses on comparing {opt$compare}")

  # The actual figure creation (usa fill_var dinámicamente)
  ggplot(my_sum, aes(x=group_label, y=mean, fill=.data[[fill_var]])) +
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
  labs(title=my_title, y=opt$metric, x="Grouping", fill=fill_var) +
  theme_bw() + 
  theme(text = element_text(family = "sans", size=18),
        # Rejilla principal muy tenue
        panel.grid.major = element_line(color = "grey90"),
        # Elimina rejilla secundaria
        panel.grid.minor = element_blank(),
        plot.title = element_text(size=14, face="bold", margin=margin(b=10), hjust=0.5),
        axis.text.x = element_text(angle=45, hjust=1),
        # Mover la leyenda arriba
        legend.position = "top"
       ) +
  get_scale(opt$mode)


  ggsave(opt$output, width=14, height=7)
  system(paste("xdg-open", opt$output))


} else if (opt$mode == "batch" || length(apps_to_filter) == 1) {
  
  # Creates one plot per requested app

  for (app in apps_to_filter) {
    # Filters only this app
    app_data <- all_data[all_data$App == app, ]
    
    if (nrow(app_data) == 0) next

    # Label to filter by config and conditional branch predictor
    app_data <- app_data %>%
      mutate(group_label = paste(config, cond_bp, sep="\n"))

    # Calculates mean
    my_sum <- app_data %>%
    group_by(group_label, config, cond_bp) %>%
    summarise( 
        n=n(),
        mean=mean(.data[[opt$metric]]),
        .groups = "drop"
    )

    # The actual figure creation
    ggplot(my_sum, aes(x=group_label, y=mean, fill=config)) +
    scale_fill_paletteer_d("beyonce::X72") +
    geom_bar(stat="identity", position=position_dodge(width=0.8), 
            width=0.7, 
            # Contorno negro para definir la barra
            color = "black",
            # Grosor del contorno
            linewidth = 0.3,
            # Un poco de transparencia para suavizar el tono)
            #alpha = 0.85
            ) +
    labs(title=glue("Relation between {opt$metric} and configurations using the SPEC17 app {app}"), y=opt$metric, x="Core + Branch Predictor") +
    theme_bw() + 
    theme(text = element_text(family = "sans", size = 18),
          # Rejilla principal muy tenue
          panel.grid.major = element_line(color = "grey90"),
          # Elimina rejilla secundaria
          panel.grid.minor = element_blank(),
          plot.title = element_text(size=14, face="bold", margin=margin(b=10), hjust=0.5),
          #axis.text.x  = element_text(size=14, angle=45, hjust=1),
          axis.title.x = element_text(margin = margin(t = 10)),  # separa el título de las etiquetas
          # Mover la leyenda arriba
          legend.position = "top"
        ) +
    get_scale(opt$mode)
    
    # Generates a unique file for each app
    app_num <- str_extract(app, "^[0-9]+")
    output_file <- str_replace(opt$output, "\\.png$", paste0("_", app_num, ".png"))
    ggsave(output_file, width=10, height=6)
  }


} else if (opt$mode == "series" && length(apps_to_filter) > 1) {

  # 1. Calcula el promedio métrico agrupando por App, config y predictor
  app_sum <- all_data %>%
  group_by(App, config, cond_bp) %>%
  summarise( 
      n = n(),
      mean = mean(.data[[opt$metric]]),
      .groups = "drop"
  )

  # 2. Calcula el promedio general (Mean) para cada combinación config + predictor
  mean_sum <- all_data %>%
  group_by(config, cond_bp) %>%
  summarise( 
      n = n(),
      mean = mean(.data[[opt$metric]]),
      .groups = "drop"
  ) %>%
  mutate(App = "Average") # Because it has no App tag

  # 3. Unimos ambos conjuntos de datos
  my_sum <- bind_rows(app_sum, mean_sum)

  # 4. Aseguramos el orden del eje X para que "Mean" siempre salga a la derecha del todo
  app_levels <- c(unique(app_sum$App), "Average")
  my_sum$App <- factor(my_sum$App, levels = app_levels)

  # 5. Creamos la etiqueta que diferenciará las barras (Config + BP)
  my_sum <- my_sum %>%
  mutate(fill_label = paste(config, cond_bp, sep="\n"))

  # Títulos
  my_title = glue("Relation between {opt$metric} and configurations per SPEC17 App plus their average")
  my_subtitle = "Includes an overall 'Mean' of the selected applications"

  # The title and subtitle for the plot
  if (is.null(opt$apps)) {
    my_title = glue("Relation between {opt$metric} and configurations per SPEC17 App plus their average")
  } else {
    my_title = glue("Relation between {opt$metric} and configurations using these SPEC17 apps:")
    my_subtitle = glue("{apps_studied}")
  }

  # 6. Creación del gráfico
  ggplot(my_sum, aes(x=App, y=mean, fill=fill_label)) +
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
  labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="Application", fill="Core + Branch Predictor") +
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
  get_scale(opt$mode)

  # Guardamos el gráfico con un ancho mayor para acomodar todas las apps cómodamente
  ggsave(opt$output, width=18, height=7)
  system(paste("xdg-open", opt$output))

} else {
  print("Something went wrong with the mode and/or the app selection, no graphs generated")
}