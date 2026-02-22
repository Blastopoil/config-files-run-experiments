#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(corrplot)
})

# --- 1. Arguments ---
option_list <- list(
    make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Input folder [default %default]", metavar="DIR"),

    make_option(c("-p", "--predictors"), type="character", 
              help="Branch predictors to study (ej: 'TAGE_SC_L,LocalBP')", metavar="LIST"),

    make_option(c("-a", "--apps"), type="character", default=NULL,
              help="Filtrar apps específicas (opcional incluso en batch) [default NULL]", metavar="LIST"),

    make_option(c("-o", "--operation"), type="character", default="cor",
              help="Mode: cor | mean | fisher | median", metavar="STRING")
)

opt <- parse_args(OptionParser(option_list=option_list))

# --- 2. Load Data ---
file <- list.files(path = opt$input, pattern = "config_experiments_data.csv", full.names = TRUE)
if(length(file) == 0) stop("No .csv file was found")

all_data <- data.frame()

temp_data <- read.csv(file)
all_data <- rbind(all_data, temp_data)

# --- 3. Data Processing ---
# Filters data acording to the passed arguments

# Filters the Branch Predictors
if (!is.null(opt$predictors) && nzchar(opt$predictors)) {
  predictors_filtrar <- trimws(strsplit(opt$predictors, ",")[[1]])
  predictors_filtrar[predictors_filtrar == "TAGE_SC_L"] <- "TAGE_SC_L_64KB"
  all_data <- all_data[all_data$cond_bp %in% predictors_filtrar, ]
}

# SPEC17 Integer
# -a 500,502,505,520,523,525,531,541,548,557
# SPEC17 Floating Point
# -a 503,507,508,510,511,519,521,526,527,538,544,549,554
# Normales
# -a 507,508,510,519,521,526,544,548,549,557

# Filters the SPEC17 apps
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

#apps_filtrar <- c("544.nab_r")

# Calculates new data

all_data$MissRate <- 100 * all_data$wrong_cond_predicts / all_data$total_cond_predicts
all_data$MPKI <- 1000 * all_data$wrong_cond_predicts / all_data$Sim_Is

op <- NULL
if (opt$operation == "cor") {
  op <- function(x, y) {
    cor(all_data[[x]], all_data[[y]], use = "pairwise.complete.obs")
  }
}
if (opt$operation == "mean") {
  apps <- split(all_data, all_data$App)
  op <- function(x, y) {
    vals <- sapply(apps, function(df) cor(df[[x]], df[[y]], use = "pairwise.complete.obs"))
    mean(vals, na.rm = TRUE)
  }
}
if (opt$operation == "fisher") {
  apps <- split(all_data, all_data$App)
  op <- function(x, y) {
    vals <- sapply(apps, function(df) cor(df[[x]], df[[y]], use = "pairwise.complete.obs"))
    vals <- vals[!is.na(vals)]
    if (length(vals) == 0) return(NA_real_)
    mean_z <- mean(atanh(vals))
    tanh(mean_z)
  }
}
if (opt$operation == "median") {
  apps <- split(all_data, all_data$App)
  op <- function(x, y) {
    vals <- sapply(apps, function(df) cor(df[[x]], df[[y]], use = "pairwise.complete.obs"))
    vals <- vals[!is.na(vals)]
    if (length(vals) == 0) return(NA_real_)
    median(vals)
  }
}

if (is.null(op)) {
  stop("The passed operation is not valid, it must be cor | mean | fisher | ")
}

# MissRate
cor_frontend_width_missrate <- op("frontend_width", "MissRate")
cor_backend_width_missrate  <- op("backend_width",  "MissRate")
cor_commit_width_missrate   <- op("commit_width",   "MissRate")
cor_rob_entries_missrate    <- op("rob_entries",    "MissRate")
cor_lq_entries_missrate     <- op("lq_entries",     "MissRate")
cor_sq_entries_missrate     <- op("sq_entries",     "MissRate")
cor_iq_entries_missrate     <- op("iq_entries",     "MissRate")
cor_int_regs_missrate       <- op("int_regs",       "MissRate")
cor_float_regs_missrate     <- op("float_regs",     "MissRate")

# IPC
cor_frontend_width_ipc <- op("frontend_width", "IPC")
cor_backend_width_ipc  <- op("backend_width",  "IPC")
cor_commit_width_ipc   <- op("commit_width",   "IPC")
cor_rob_entries_ipc    <- op("rob_entries",    "IPC")
cor_lq_entries_ipc     <- op("lq_entries",     "IPC")
cor_sq_entries_ipc     <- op("sq_entries",     "IPC")
cor_iq_entries_ipc     <- op("iq_entries",     "IPC")
cor_int_regs_ipc       <- op("int_regs",       "IPC")
cor_float_regs_ipc     <- op("float_regs",     "IPC")

# MPKI
cor_frontend_width_mpki <- op("frontend_width", "MPKI")
cor_backend_width_mpki  <- op("backend_width",  "MPKI")
cor_commit_width_mpki   <- op("commit_width",   "MPKI")
cor_rob_entries_mpki    <- op("rob_entries",    "MPKI")
cor_lq_entries_mpki     <- op("lq_entries",     "MPKI")
cor_sq_entries_mpki     <- op("sq_entries",     "MPKI")
cor_iq_entries_mpki     <- op("iq_entries",     "MPKI")
cor_int_regs_mpki       <- op("int_regs",       "MPKI")
cor_float_regs_mpki     <- op("float_regs",     "MPKI")

# Creates the correlation matrix
correlation_matrix <- matrix(
  c(
    cor_frontend_width_missrate, cor_frontend_width_ipc, cor_frontend_width_mpki,
    cor_backend_width_missrate,  cor_backend_width_ipc,  cor_backend_width_mpki,
    cor_commit_width_missrate,   cor_commit_width_ipc,   cor_commit_width_mpki,
    cor_rob_entries_missrate,    cor_rob_entries_ipc,    cor_rob_entries_mpki,
    cor_lq_entries_missrate,     cor_lq_entries_ipc,     cor_lq_entries_mpki,
    cor_sq_entries_missrate,     cor_sq_entries_ipc,     cor_sq_entries_mpki,
    cor_iq_entries_missrate,     cor_iq_entries_ipc,     cor_iq_entries_mpki,
    cor_int_regs_missrate,       cor_int_regs_ipc,       cor_int_regs_mpki,
    cor_float_regs_missrate,     cor_float_regs_ipc,     cor_float_regs_mpki
  ),
  nrow = 9,
  byrow = TRUE,
  dimnames = list(
    c("frontend_width", "backend_width", "commit_width", "rob_entries",
      "lq_entries", "sq_entries", "iq_entries", "int_regs", "float_regs"),
    c("MissRate", "IPC", "MPKI")
  )
)

# Imprimir tabla
cat("\n=== Correlation Matrix ===\n\n")
print(correlation_matrix, row.names = TRUE)

plot_data <- correlation_matrix

#corrplot(plot_data, method = "color", col = gray(seq(0,1,length=100)))

# From https://cran.r-project.org/web/packages/corrplot/vignettes/corrplot-intro.html
corrplot(plot_data, method = 'number') # colorful number