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
  make_option(c("--input_se"), type="character", default="./2-parser-output/32k_btb",
              help="Input folder for SE simulations [default %default]", metavar="DIR"),
              
  make_option(c("--input_fs"), type="character", default="./2-parser-output/fs/32k",
              help="Input folder for FS simulations [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="delta_grafico.png",
              help="Output base file name [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Metric (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_SC_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-c", "--configs"), type="character", default=NULL,
            help="Filter core configs (ex: 'BigO3,SmallO3') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filters specific SPEC17 rate apps (none if not passed).\n\t\t'int' uses all SPEC17int apps\n\t\t'float' the SPEC17float apps\n\t\t'normal' a custom set of apps", metavar="LIST")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
# Function to load and tag data from a specific mode
load_and_tag_data <- function(folder, exec_mode) {
  files <- list.files(path = folder, pattern = "*_simple_data.csv", full.names = TRUE)
  if(length(files) == 0) return(data.frame())
  
  mode_data <- data.frame()
  for (file in files) { 
    temp_data <- read.csv(file, stringsAsFactors = FALSE, na.strings = c("N/A", "NA", "NaN", "nan"))
    temp_data <- temp_data[complete.cases(temp_data), ]
    
    # Extract core config from filename (ignoring prefix like fs_ or suffix)
    filename <- basename(file)
    core_config <- ifelse(str_detect(filename, "BigO3"), "BigO3", 
                   ifelse(str_detect(filename, "SmallO3"), "SmallO3", "Unknown"))
    
    temp_data$core_config <- core_config
    temp_data$exec_mode <- exec_mode
    mode_data <- rbind(mode_data, temp_data)
  }
  return(mode_data)
}

data_se <- load_and_tag_data(opt$input_se, "SE")
data_fs <- load_and_tag_data(opt$input_fs, "FS")

if (nrow(data_se) == 0 || nrow(data_fs) == 0) {
  stop("Missing data in either SE or FS folder.")
}

all_data <- rbind(data_se, data_fs)

# --- 3. Data Processing ---
# Filters the Branch Predictors
if (!is.null(opt$predictors) && nzchar(opt$predictors)) {
  predictors_filter <- trimws(strsplit(opt$predictors, ",")[[1]])
  all_data <- all_data[all_data$cond_bp %in% predictors_filter, ]
}

# Filters the core configs
if (!is.null(opt$configs) && nzchar(opt$configs)) {
  configs_filter <- trimws(strsplit(opt$configs, ",")[[1]])
  all_data <- all_data[all_data$core_config %in% configs_filter, ]
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
  mutate(
    across(c(Sim_Is, total_cond_predicts, wrong_cond_predicts, branch_mispredicts_at_execute), ~ suppressWarnings(as.numeric(.x))),
    MPKI_spec = ifelse(is.finite(branch_mispredicts_at_execute / Sim_Is), (branch_mispredicts_at_execute / Sim_Is) * 1000, NA_real_),
    MPKI = ifelse(is.finite(wrong_cond_predicts / Sim_Is), (wrong_cond_predicts / Sim_Is) * 1000, NA_real_),
    CondMissRate = ifelse(is.finite(wrong_cond_predicts / total_cond_predicts), (wrong_cond_predicts / total_cond_predicts) * 100, NA_real_)
  )

if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

# Average functions protected against NA and 0s
get_average_function <- function() {
    if (opt$metric == "IPC") {
        function(x) {
          x <- suppressWarnings(as.numeric(x))
          x <- x[is.finite(x) & x > 0]
          if (length(x) == 0) return(NA_real_)
          exp(mean(log(x)))
        }
    } else {
        function(x) mean(as.numeric(x), na.rm = TRUE)
    }
}

# --- 4. Delta Calculation ---
# Calculate means independently for SE and FS
sum_se <- all_data %>% filter(exec_mode == "SE") %>%
  group_by(App, core_config, cond_bp) %>%
  summarise(val_se = get_average_function()(.data[[opt$metric]]), .groups = "drop")

sum_fs <- all_data %>% filter(exec_mode == "FS") %>%
  group_by(App, core_config, cond_bp) %>%
  summarise(val_fs = get_average_function()(.data[[opt$metric]]), .groups = "drop")

# Join and calculate % difference (SE relative to FS baseline)
delta_data <- inner_join(sum_se, sum_fs, by = c("App", "core_config", "cond_bp")) %>%
  mutate(delta_percent = ifelse(is.finite(val_fs) & val_fs != 0, ((val_se - val_fs) / val_fs) * 100, NA_real_)) %>%
  filter(is.finite(delta_percent))

# Calculate the general average (Mean) for each config + predictor combination
mean_sum <- delta_data %>%
  group_by(core_config, cond_bp) %>%
  summarise(delta_percent = mean(delta_percent, na.rm = TRUE), .groups = "drop") %>%
  mutate(App = "Average")

# Join the app deltas with the average
my_sum <- bind_rows(delta_data, mean_sum)

# Ensure the X axis order puts "Average" at the very right
app_levels <- c(unique(delta_data$App), "Average")
my_sum$App <- factor(my_sum$App, levels = app_levels)

# --- 5. Graph Creation ---
my_title = glue("Difference between SE and FS execution modes for {opt$metric}")

if (is.null(opt$apps) || opt$apps == "all") {
  my_subtitle = glue("Percentage of deviation ((SE - FS) / FS) * 100 - All apps and average")
} else if (opt$apps == "int") {
  my_subtitle = glue("Percentage of deviation ((SE - FS) / FS) * 100 - SPEC int apps")
} else if (opt$apps == "float") {
  my_subtitle = glue("Percentage of deviation ((SE - FS) / FS) * 100 - SPEC float apps")
} else {
  my_subtitle = glue("Percentage of deviation ((SE - FS) / FS) * 100")
}

is_all <- length(apps_to_filter) > 15
is_wide_plot <- length(apps_to_filter) > 12
is_svg <- grepl("\\.svg$", opt$output, ignore.case = TRUE)

if (is_all) {
  base_text_size <- 13
  title_size <- 18
  subtitle_size <- 16
  bar_label_size <- 2.5
} else {
  base_text_size <- ifelse(is_wide_plot, 25, 18)
  title_size <- ifelse(is_wide_plot, 25, 18)
  subtitle_size <- ifelse(is_wide_plot, 22, 16)
  bar_label_size <- ifelse(is_wide_plot, 4.2, 3)
}

my_linewidth <- ifelse(is_svg, 0.5, 0.3)

# The scale for percentage plots (Dynamic expansion)
get_percentage_scale <- function() {
  if (opt$metric == "IPC") {
    scale_y_continuous( 
      # Líneas principales cada 0.5 unidades
      limits = c(-40, 80),
      breaks = seq(-40, 80, by = 20), 
      # Líneas finas cada 0.1 unidades para lectura precisa
      minor_breaks = seq(-40, 80, by = 20),
      # Hace que las barras toquen el eje X (mult = c(abajo, arriba))
      expand = expansion(mult = c(0, 0.05)),
      # Formato de etiquetas con un decimal y símbolo de porcentaje
      labels = function(x) paste0(x, "%")
    )
  } else {
    scale_y_continuous(
      labels = function(x) paste0(x, "%"),
      expand = expansion(mult = c(0.1, 0.1))
    )
  }
}

# Plot generation
ggplot(my_sum, aes(x=App, y=delta_percent, fill=cond_bp)) +
  # Using facet_wrap to separate BigO3 and SmallO3 clearly
  facet_wrap(~ core_config, ncol = 1, scales = "fixed") +
  scale_fill_paletteer_d("nationalparkcolors::Arches") +
  
  # The 0% baseline (Ideal scenario where SE == FS)
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  
  geom_bar(stat="identity", position=position_dodge(width=0.8), 
           width=0.7, 
           color = "black",
           linewidth = my_linewidth
          ) +
  geom_text(
      aes(label = sprintf("%+.1f%%", delta_percent)),
      position = position_dodge(width = 0.8),
      # Adjust Vjust depending if the bar is positive or negative
      vjust = ifelse(my_sum$delta_percent >= 0, -0.3, 1.3),
      size = bar_label_size,
      show.legend = FALSE
      ) +
  labs(title=my_title, subtitle=my_subtitle, y=paste("SE Error Margin on", opt$metric), x="Application", fill="Branch Predictor") +
  theme_bw() + 
  theme(text = element_text(family = "sans", size = base_text_size),
        panel.grid.major = element_line(color = "grey70"),
        panel.grid.minor = element_blank(),
        
        # Facet strip formatting
        strip.background = element_rect(fill="grey90", color="black"),
        strip.text = element_text(face="bold", size=base_text_size),
        
        plot.title = element_text(size=title_size, face="bold", hjust=0, margin=margin(b=5)),
        plot.subtitle = element_text(size=subtitle_size, face="bold", hjust=0, margin=margin(b=25)),
        
        legend.position = "top",
        legend.justification = "right",
        legend.direction = "horizontal",
        legend.box.margin = margin(t = -40, b = 0, r = 0, l = 0),
        legend.margin = margin(t = 0, b = 0),
        
        axis.title.x = element_text(margin = margin(t = 10)),
        axis.text.x = element_text(angle = 45, hjust = 1)
       ) +
  get_percentage_scale()

# Guardamos el gráfico con un ancho mayor para acomodar todas las apps cómodamente
if (opt$apps == "float" || is_all) {
  ggsave(opt$output, width=25, height=12)
} else {
  ggsave(opt$output, width=18, height=10) # Mayor altura para que los facets respiren
}

# --- 6. Inyectar el comando como metadato ---
args_pasados <- commandArgs(trailingOnly = TRUE)
comando_ejecutado <- paste("Rscript data-graphing/plot_delta_se_fs.R", paste(args_pasados, collapse = " "))

comando_exif <- sprintf("exiftool -q -overwrite_original -Comment='%s' %s", comando_ejecutado, opt$output)

exit_code <- system(comando_exif)

if (exit_code != 0) {
  warning("No se pudo inyectar el metadato. ¿Tienes 'exiftool' instalado en tu sistema?")
}

system(paste("xdg-open", opt$output))