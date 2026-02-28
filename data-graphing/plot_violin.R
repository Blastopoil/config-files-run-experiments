#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ggplot2)
  library(ggthemes)
  library(paletteer)
  library(dplyr)
  library(svglite)
  library(ggstatsplot)
})

# --- 1. Arguments ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Carpeta de entrada [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-M", "--Mode"), type="character", default="ggplot",
              help="'ggplot': uses ggplot to make the plots\n\t\t'ggstatsplot': uses ggbetweenstats to make the plots\n\t\t[default %default]"),
  
  make_option(c("-A", "--App_Group"), type="character", default="IPC",
              help="Attention! This argument is only used in 'ggstatsplot' mode [default %default]", metavar="STR")
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

int_apps <- c(
  "500.perlbench", "502.gcc", "505.mcf", "520.omnetpp", 
  "523.xalancbmk", "525.x264", "531.deepsjeng", "541.leela", 
  "548.exchange2", "557.xz"
)

float_apps <- c(
  "503.bwaves", "507.cactuBSSN", "508.namd", "510.parest", 
  "511.povray", "519.lbm", "521.wrf", "526.blender", 
  "527.cam4", "538.imagick", "544.nab", "549.fotonik3d", 
  "554.roms"
)

og_data <- all_data
all_data <- all_data %>%
    mutate(
        App_Group = case_when(
            App %in% int_apps ~ "SPEC17 Integer",
            App %in% float_apps ~ "SPEC17 Floating Point",
            TRUE ~ "Unknown"
        )
    )
og_data <- og_data %>%
    mutate(
        App_Group = "All SPEC17 Apps"
    )

all_data <- rbind(all_data, og_data)

# Adds columns

all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)

if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Metric not found:", opt$metric))
}

#print(all_data)

# --- 4. Graph Creation ---

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
get_scale <- function() {
  if (opt$metric == "IPC") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      limits = c(0, 4.5),
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
                      limits = c(0, 35),
                      breaks = seq(0, 70, by = 5), 
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  }
}
get_y <- function() {
    if (opt$metric == "IPC") {
        all_data$IPC
    } else if (opt$metric == "MPKI") {
        all_data$MPKI
    } else if (opt$metric == "CondMissRate") {
        all_data$CondMissRate
    } else {
        stop(paste("Metric not found:", opt$metric))
    }
}
get_palette <- function() {
    #"nationalparkcolors::Arches" # para 2 y para 3
    #"awtools::ppalette" # parece de payaso, pero sirve para muchos grupos
    "feathers::bee_eater"
}

if (opt$Mode == "ggplot") {
    
    # Label to filter by config and conditional branch predictor
    all_data <- all_data %>%
    mutate(group_label = paste(config, cond_bp, sep="\n"))

    app_levels <- c(unique(all_data$App_Group), "Average")
    all_data$App_Group <- factor(all_data$App_Group, levels = app_levels)

    # The title and subtitle for the plot
    my_title = "Dispersion of the different SPEC apps"
    my_subtitle = NULL

    # The actual figure creation
    ggplot(all_data, aes(x=App_Group, y=get_y(), fill=group_label)) +
    scale_fill_paletteer_d(get_palette()) +
    geom_violin(position="dodge", alpha=0.5, outlier.colour="transparent") +
    labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="SPEC Apps") +
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


} else if (opt$Mode == "ggstatsplot") {

    metric_sym <- rlang::sym(opt$metric)

    # Filters the App Group
    if (!is.null(opt$App_Group) && nzchar(opt$App_Group)) {
        app_groups_filter <- trimws(strsplit(opt$App_Group, ",")[[1]])
        all_data <- all_data[all_data$App_Group %in% app_groups_filter, ]
    }

    # Label to filter by config and conditional branch predictor
    all_data <- all_data %>%
    mutate(group_label = paste(config, cond_bp, sep="\n"))

    app_levels <- c(unique(all_data$App_Group), "Average")
    all_data$App_Group <- factor(all_data$App_Group, levels = app_levels)

    # The title and subtitle for the plot
    my_title = "Dispersion of the different SPEC apps"
    my_subtitle = NULL

    # The actual figure creation

    plt <- ggbetweenstats(
        data = all_data,
        x = group_label,
        y = !!metric_sym,
        results.subtitle = FALSE,      # Quita el test estadístico superior (F, p-valor)
        bf.message = FALSE,            # Quita el factor bayesiano inferior derecho
        centrality.plotting = TRUE,   # Quita el punto rojo grande y la caja con la media
        pairwise.comparisons = FALSE)   # Quita las anotaciones del eje Y derecho)
    plt <- plt + 
        # Add labels and title
        labs(
            x = "Configuration and Branch Predictor",
            y = opt$metric,
            title = "Distribution of metric across different configurations and branch predictors"
        ) + 
        # Customizations
        theme(
            # This is the new default font in the plot
            text = element_text(family = "Roboto", size = 8, color = "black"),
            plot.title = element_text(
            family = "Lobster Two", 
            size = 20,
            face = "bold",
            color = "#2a475e"
            ),
            # Statistical annotations below the main title
            plot.subtitle = element_text(
            family = "Roboto", 
            size = 15, 
            face = "bold",
            color="#1b2838"
            ),
            plot.title.position = "plot", # slightly different from default
            axis.text = element_text(size = 10, color = "black"),
            axis.title = element_text(size = 12)
        )
    

    ggsave(opt$output, width=10, height=6)
    system(paste("xdg-open", opt$output))

} else if (opt$Mode == "ggplot2") {

    # Filters the App Group
    if (!is.null(opt$App_Group) && nzchar(opt$App_Group)) {
        app_groups_filter <- trimws(strsplit(opt$App_Group, ",")[[1]])
        all_data <- all_data[all_data$App_Group %in% app_groups_filter, ]
    }

    # Label to filter by config and conditional branch predictor
    all_data <- all_data %>%
    mutate(group_label = paste(cond_bp, config, sep="\n"))

    app_levels <- c(unique(all_data$App_Group), "Average")
    all_data$App_Group <- factor(all_data$App_Group, levels = app_levels)

    # The title and subtitle for the plot
    my_title = "Dispersion of the different SPEC apps"
    my_subtitle = NULL

    # The actual figure creation
    ggplot(all_data, aes(x=group_label, y=get_y(), fill=group_label)) +
    scale_fill_paletteer_d(get_palette()) +
    geom_violin(position="dodge", alpha=0.5, outlier.colour="transparent") +
    geom_boxplot(width=0.15, alpha = 0.8, color="black", 
                 outlier.shape = NA) +
    geom_jitter(width=0.1, size=2, alpha=0.6, color="black") +
    labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="SPEC Apps") +
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
        legend.position = "none"
        ) +
    get_scale()


    ggsave(opt$output, width=10, height=6)
    system(paste("xdg-open", opt$output))

} else {
    stop(paste("Mode not found:", opt$Mode))
}