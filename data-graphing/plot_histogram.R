#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ggplot2)
  library(dplyr)
  library(glue)
})

# --- 1. Arguments ---
option_list <- list(
  make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Carpeta de entrada [default %default]", metavar="DIR"),
  
  make_option(c("-o", "--output"), type="character", default="grafico.png",
              help="Nombre base del archivo de salida. En modo batch se añade el sufijo _APPNUM [default %default]", metavar="FILE"),
  
  make_option(c("-m", "--metric"), type="character", default="IPC",
              help="Métrica (IPC, MPKI, CondMissRate) [default %default]", metavar="STR"),
  
  make_option(c("-c", "--config"), type="character", default="ALL",
              help="Config (ex: 'BigO3,SmallO3') [default %default]", metavar="LIST"),
  
  make_option(c("-p", "--predictors"), type="character", default=NULL,
              help="Predictors (ex: 'TAGE_L,LocalBP') [default %default]", metavar="LIST"),
  
  make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filtrar apps específicas (opcional incluso en batch) [default NULL]", metavar="LIST"),
  
  make_option(c("-B", "--batch"), action="store_true", default=FALSE,
              help="Si se activa, genera una gráfica individual por cada App encontrada automáticamente.")
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

# SPEC17 Integer
# -a 500,502,505,520,523,525,531,541,548,557
# SPEC17 Floating Point
# -a 503,507,508,510,511,519,521,526,527,538,544,549,554
# Normales
# -a 507,508,510,519,521,526,544,548,549,557

# Filters the SPEC17 apps
apps_to_filter <- NULL
if (!is.null(opt$apps) && nzchar(opt$apps)) {
  apps_to_filter <- trimws(strsplit(opt$apps, ",")[[1]])
  spec17_app_map <- c(
    "500" = "500.perlbench_r", "502" = "502.gcc_r", "503" = "503.bwaves_r", "505" = "505.mcf_r", 
    "507" = "507.cactuBSSN_r", "508" = "508.namd_r", "510" = "510.parest_r", "511" = "511.povray_r", 
    "519" = "519.lbm_r", "520" = "520.omnetpp_r", "521" = "521.wrf_r", "523" = "523.xalancbmk_r", 
    "525" = "525.x264_r", "526" = "526.blender_r", "527" = "527.cam4_r", "531" = "531.deepsjeng_r",
    "538" = "538.imagick_r", "541" = "541.leela_r", "544" = "544.nab_r", "548" = "548.exchange2_r", 
    "549" = "549.fotonik3d_r", "554" = "554.roms_r", "557" = "557.xz_r"
  )
  # Converts to full app name
  apps_to_filter <- ifelse(
    apps_to_filter %in% names(spec17_app_map),
    unname(spec17_app_map[apps_to_filter]),
    apps_to_filter
  )
  # Makes the actual filtering
  all_data <- all_data[all_data$App %in% apps_to_filter, ]
}

print(all_data)

# Adds columns

all_data <- all_data %>%
  mutate(MPKI = (wrong_cond_predicts / Sim_Is) * 1000) %>%
  mutate(CondMissRate = (wrong_cond_predicts / total_cond_predicts) * 100)


if (!(opt$metric %in% colnames(all_data))) {
  stop(paste("Métrica no encontrada:", opt$metric))
}

# --- 4. Graph Creation ---

# Creates one plot for all the apps or a set
if (!opt$batch && is.null(apps_to_filter)) {

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

    # Confidence interval
    ggplot(my_sum, aes(x=group_label, y=mean, fill=config)) +
    geom_bar(stat="identity", position=position_dodge(), width=0.7, alpha=0.9) +
    geom_errorbar(aes(ymin=mean-ic, ymax=mean+ic), width=0.4, colour="orange", alpha=0.9, linewidth=1.5, position=position_dodge(0.7)) +
    labs(title=glue("Relation between {opt$metric} and the following configurations"), y=opt$metric, x="Core + Branch Predictor")
    
    ggsave(opt$output, width=10, height=6)
}
# Creates one plot for a set of apps
if (!opt$batch && !is.null(apps_to_filter)) {

    # Label to filter by config, conditional branch predictor and apps
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

    apps_studied <- paste(apps_to_filter, collapse=", ")
    # Confidence interval
    ggplot(my_sum, aes(x=group_label, y=mean, fill=config)) +
    geom_bar(stat="identity", position=position_dodge(), width=0.7, alpha=0.9) +
    geom_errorbar(aes(ymin=mean-ic, ymax=mean+ic), width=0.4, colour="orange", alpha=0.9, linewidth=1.5, position=position_dodge(0.7)) +
    labs(title=glue("Relation between {opt$metric} and configurations using these SPEC17 apps: {apps_studied}"), y=opt$metric, x="Core + Branch Predictor") +
    theme(plot.title = element_text(size=10, face="bold", margin=margin(b=10), hjust=0.5),
          axis.text.x = element_text(angle=45, hjust=1))
    
    ggsave(opt$output, width=10, height=6)
}

