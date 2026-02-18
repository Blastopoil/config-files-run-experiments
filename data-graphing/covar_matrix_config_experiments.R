#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(corrplot)
})

# --- 1. Arguments ---
option_list <- list(
    make_option(c("-i", "--input"), type="character", default="./2-parser-output",
              help="Carpeta de entrada [default %default]", metavar="DIR"),

    make_option(c("-p", "--predictors"), type="character", 
              help="Predictores (ej: 'TAGE_SC_L,LocalBP')", metavar="LIST")
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

all_data <- all_data[all_data$cond_bp == opt$predictors, ]

# SPEC17 Floating Point
#apps_filtrar <- c("503.bwaves_r", "507.cactuBSSN_r", "508.namd_r", "510.parest_r", "511.povray_r", "519.lbm_r", "521.wrf_r",
#                  "526.blender_r", "527.cam4_r", "538.imagick_r", "544.nab_r", "549.fotonik3d_r", "554.roms_r")

# SPEC17 Integer
#apps_filtrar <- c("500.perlbench_r", "502.gcc_r", "505.mcf_r", "520.omnetpp_r", "523.xalancbmk_r", "525.x264_r", 
#                  "531.deepsjeng_r", "541.leela_r", "548.exchange2_r", "557.xz_r")

apps_filtrar <- c("544.nab_r")

all_data <- all_data[all_data$App %in% apps_filtrar, ]

# Calculates new data

all_data$MissRate <- 100 * all_data$wrong_cond_predicts / all_data$total_cond_predicts
all_data$MPKI <- 1000 * all_data$wrong_cond_predicts / all_data$Sim_Is

# Correlation with MissRate
cor_frontend_width_missrate <- cor(all_data$frontend_width, all_data$MissRate)
cor_backend_width_missrate <- cor(all_data$backend_width, all_data$MissRate)
cor_commit_width_missrate <- cor(all_data$commit_width, all_data$MissRate)
cor_rob_entries_missrate <- cor(all_data$rob_entries, all_data$MissRate)
cor_lq_entries_missrate <- cor(all_data$lq_entries, all_data$MissRate)
cor_sq_entries_missrate <- cor(all_data$sq_entries, all_data$MissRate)
cor_iq_entries_missrate <- cor(all_data$iq_entries, all_data$MissRate)
cor_int_regs_missrate <- cor(all_data$int_regs, all_data$MissRate)
cor_float_regs_missrate <- cor(all_data$float_regs, all_data$MissRate)

# Correlation with IPC
cor_frontend_width_ipc <- cor(all_data$frontend_width, all_data$IPC)
cor_backend_width_ipc <- cor(all_data$backend_width, all_data$IPC)
cor_commit_width_ipc <- cor(all_data$commit_width, all_data$IPC)
cor_rob_entries_ipc <- cor(all_data$rob_entries, all_data$IPC)
cor_lq_entries_ipc <- cor(all_data$lq_entries, all_data$IPC)
cor_sq_entries_ipc <- cor(all_data$sq_entries, all_data$IPC)
cor_iq_entries_ipc <- cor(all_data$iq_entries, all_data$IPC)
cor_int_regs_ipc <- cor(all_data$int_regs, all_data$IPC)
cor_float_regs_ipc <- cor(all_data$float_regs, all_data$IPC)

# Correlation with MPKI
cor_frontend_width_mpki <- cor(all_data$frontend_width, all_data$MPKI)
cor_backend_width_mpki <- cor(all_data$backend_width, all_data$MPKI)
cor_commit_width_mpki <- cor(all_data$commit_width, all_data$MPKI)
cor_rob_entries_mpki <- cor(all_data$rob_entries, all_data$MPKI)
cor_lq_entries_mpki <- cor(all_data$lq_entries, all_data$MPKI)
cor_sq_entries_mpki <- cor(all_data$sq_entries, all_data$MPKI)
cor_iq_entries_mpki <- cor(all_data$iq_entries, all_data$MPKI)
cor_int_regs_mpki <- cor(all_data$int_regs, all_data$MPKI)
cor_float_regs_mpki <- cor(all_data$float_regs, all_data$MPKI)

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

corrplot(plot_data, method = "color", col = gray(seq(0,1,length=100)))