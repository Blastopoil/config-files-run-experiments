# Cargar librerías necesarias
library(readr)
library(dplyr)
library(ggplot2)

# 1. Leer los datos
df <- read_csv("./2-parser-output/delay_experiments_data.csv")

# CORRECCIÓN: Forzar la conversión de las columnas de texto a números
df <- df %>%
  mutate(
    IPC = as.numeric(IPC),
    Sim_Is = as.numeric(Sim_Is),
    wrong_cond_predicts = as.numeric(wrong_cond_predicts)
  )

# Filtramos para usar solo un predictor
df_filtrado <- df %>% filter(cond_bp == "LocalBP")

# 2. Calcular el MPKI usando solo el baseline (delay == 1)
datos_mpki <- df_filtrado %>%
  filter(general_delay == 1) %>%
  group_by(App) %>%
  summarise(
    # MPKI = (Fallos de predicción / Instrucciones Simuladas) * 1000
    MPKI = mean((wrong_cond_predicts / Sim_Is) * 1000, na.rm = TRUE),
    .groups = 'drop'
  )

# 3. Calcular la pendiente de degradación (IPC frente al delay) para cada aplicación
# Añadimos un filtro extra (!is.na(IPC)) por si alguna app falló y tiene un IPC nulo
datos_pendientes <- df_filtrado %>%
  filter(!is.na(IPC) & !is.na(general_delay)) %>%
  group_by(App) %>%
  summarise(
    pendiente = coef(lm(IPC ~ general_delay))[2],
    .groups = 'drop'
  )

# 4. Unir ambas tablas usando el nombre de la aplicación como clave
tabla_resumen <- inner_join(datos_mpki, datos_pendientes, by = "App")

# Mostrar la tabla en la consola
print("Tabla de Pendientes vs MPKI:")
print(tabla_resumen)

# 5. Crear el gráfico de dispersión con regresión lineal
grafico <- ggplot(tabla_resumen, aes(x = MPKI, y = pendiente)) +
  geom_point(color = "steelblue", size = 3, alpha = 0.8) +
  geom_text(aes(label = App), vjust = -0.8, hjust = 0.5, size = 3, check_overlap = TRUE) +
  geom_smooth(method = "lm", color = "tomato", linetype = "dashed", se = FALSE) +
  labs(
    title = "Relación entre MPKI y Degradación del IPC (Usando LocalBP)",
    x = "MPKI",
    y = "Pendiente de la degradación del IPC"
  ) +
  theme_minimal()

# Dibujar el gráfico
print(grafico)