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
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'LongGshare,Gshare,GshareMod,LongGshareMod,PartitionedGshareMod,LongPartitionedGshareMod,GshareInclusive,LongGshareInclusive,PartitionedGshareInclusive,LongPartitionedGshareInclusive') [default %default]", metavar="LIST"),
  
  make_option(c("-c", "--configs"), type="character", default=NULL,
            help="Filter core configs (ex: 'BigO3,SmallO3') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filters specific SPEC17 rate apps (none if not passed).\n\t\t'int' uses all SPEC17int apps\n\t\t'float' the SPEC17float apps\n\t\t'normal' a custom set of apps", metavar="LIST")
            
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
files <- list.files(
    path = opt$input, 
    pattern = "*_gshare_data.csv", 
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

    temp_data$config <- str_remove(basename(file), "_gshare_data.csv")
    all_data <- rbind(all_data, temp_data)
}

# --- 3. Data Processing ---
# Filters data acording to the passed arguments

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

# Adds columns

all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)


if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

#print(all_data)

# --- 4. Graph Creation ---

# For the title of the plots' creation/s
if (!is.null(opt$apps)) {
  if (opt$apps == "int") {
    apps_studied <- "(Integer) 500,502,505,520,523,525,531,541,548,557"
  } else if (opt$apps == "float") {
    apps_studied <- "(Floating Point) 503,507,508,510,511,519,521,526,527,538,544,549,554"
  } else if (opt$apps == "normal") {
    apps_studied <- "507,508,510,519,521,526,544,548,549,557"
  } else if (opt$apps == "all") {
    apps_studied <- "500,502,503,505,507,508,510,511,519,520,521,523,525,526,527,531,538,541,544,548,549,554,557"
  } else {
    apps_studied <- paste(apps_to_filter, collapse=", ")
  }
} else {
  apps_studied <- paste(apps_to_filter, collapse=", ")
}

# For the scale
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
                      limits = c(0, 90),
                      breaks = seq(0, 180, by = 5),
                      # Líneas finas cada 0.1 unidades para lectura precisa
                      minor_breaks = seq(0, 4, by = 0.1), 
                      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
                      expand = expansion(mult = c(0, 0.05)) 
                      )
    scale
  } else if (opt$metric == "CondMissRate") {
    scale <- scale_y_continuous(# Líneas principales cada 0.5 unidades
                      #limits = c(0, 20),
                      breaks = seq(0, 70, by = 2.5), 
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


# 1. Calcula el promedio métrico agrupando por App, config y predictor
app_sum <- all_data %>%
group_by(App, config, cond_bp) %>%
summarise( 
    n = n(),
    mean = get_average_function()(.data[[opt$metric]]),
    .groups = "drop"
)

# 2. Calcula el promedio general (Mean) para cada combinación config + predictor
mean_sum <- all_data %>%
group_by(config, cond_bp) %>%
summarise( 
    n = n(),
    mean = get_average_function()(.data[[opt$metric]]),
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
mutate(fill_label = paste(cond_bp, sep="\n"))

# Títulos
my_title = glue("{opt$metric} ~ {my_sum$config} + bp")
my_subtitle = "Individual apps"

# The title and subtitle for the plot
if (is.null(opt$apps)) {
  my_subtitle = glue("All apps")
} else if (opt$apps == "int") {
  my_subtitle = glue("SPEC int apps")
} else if (opt$apps == "float") {
  my_subtitle = glue("SPEC float apps")
}

# 6. Creación del gráfico
ggplot(my_sum, aes(x=App, y=mean, fill=fill_label)) +
#scale_fill_paletteer_d("nationalparkcolors::Arches") +
geom_bar(stat="identity", position=position_dodge(width=0.8), 
          width=0.7, 
          # Contorno negro para definir la barra
          color = "black",
          # Grosor del contorno
          linewidth = 0.3,
          # Un poco de transparencia para suavizar el tono)
          #alpha = 0.85
        ) +
labs(title=my_title, subtitle=my_subtitle, y=opt$metric, x="Application", fill="Branch Predictor") +
theme_bw() + 
theme(text = element_text(family = "sans", size = 18),
      # Rejilla principal muy tenue
      panel.grid.major = element_line(color = "grey90"),
      # Elimina rejilla secundaria
      panel.grid.minor = element_blank(),
      
      # 1. Alineación a la izquierda y sin márgenes extra que empujen el texto
      plot.title = element_text(size=18, face="bold", hjust=0, margin=margin(b=0)),
      plot.subtitle = element_text(size=16, face="bold", hjust=0, margin=margin(b=0)),
      
      # 2. Configuración de la leyenda
      legend.position = "top",
      legend.justification = "right",
      legend.direction = "horizontal",
      
      # 3. El truco: margen negativo superior para que la leyenda suba
      # Ajusta el -40 según necesites (más negativo = más arriba)
      legend.margin = margin(t = -20, b = 0),
      
      axis.title.x = element_text(margin = margin(t = 10))
      ) +
get_scale()

# Guardamos el gráfico con un ancho mayor para acomodar todas las apps cómodamente
if (opt$apps == "all" || length(apps_to_filter) > 12) {
  ggsave(opt$output, width=25, height=6)
} else {
  ggsave(opt$output, width=18, height=6)
}
system(paste("xdg-open", opt$output))
