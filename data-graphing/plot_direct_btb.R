# 1. Cargar las librerías necesarias
# Si no las tienes instaladas, ejecuta primero: install.packages(c("readr", "dplyr", "ggplot2"))
library(readr)
library(dplyr)
library(ggplot2)
library(earth)

# 2. Leer los datos desde el archivo CSV
df <- read_csv("./2-parser-output/btb_experiments_data.csv")

# 3. Procesar y transformar los datos
tabla_resumen <- df %>%
  # Filtrar solo los experimentos con ras_size = 64
  filter(ras_size == 64) %>%
  # Agrupar los datos por cada aplicación
  group_by(App) %>%
  summarise(
    # Calcular la pendiente de la regresión (IPC en función del log2 del BTB)
    # coef(...)[2] extrae directamente el valor numérico de la pendiente
    pendiente = coef(lm(IPC ~ log2(btb_size)))[2],

    # Extraemos el IPC en los extremos. 
    # Usamos mean() por si hubiese más de una medición para el mismo tamaño
    ipc_1024 = mean(IPC[btb_size == 1024], na.rm = TRUE),
    ipc_16384 = mean(IPC[btb_size == 16384], na.rm = TRUE),
    
    # Calculamos la pendiente (diferencia de IPC dividida entre los 4 saltos logarítmicos)
    #pendiente = (ipc_16384 - ipc_1024) / 4,
    
    # Calcular el número de saltos directos sumando llamadas, condicionales e incondicionales.
    # Se usa mean() para obtener un valor representativo si variase ligeramente entre ejecuciones.
    saltos_directos = mean((direct_calls + direct_cond + direct_uncond) / Sim_Is) * 100,
    
    .groups = 'drop'
  )

# Imprimir la tabla resultante en la consola para que puedas ver los números exactos
print("Tendencia de IPC vs Saltos Directos:")
print(tabla_resumen)

# 4. Crear el gráfico de dispersión (Scatter Plot)
grafico <- ggplot(tabla_resumen, aes(x = saltos_directos, y = pendiente)) +
  # Añadir los puntos
  geom_point(color = "steelblue", size = 3, alpha = 0.8) +
  # Añadir los nombres de las apps cerca de cada punto para identificarlas
  geom_text(aes(label = App), vjust = -0.8, hjust = 0.5, size = 3, check_overlap = TRUE) +
  # Añadir una línea de tendencia (opcional) para ver si hay correlación general
  geom_smooth(method = "lm", color = "tomato", linetype = "dashed", se = FALSE) +
  #geom_smooth(method = "lm", formula = y ~ x + I(pmax(x - 10, 0)), color = "tomato", linetype = "dashed", se = FALSE) +
  #geom_smooth(method = "earth", formula = y ~ x, se = FALSE, color = "tomato", linetype = "dashed") +
  # Títulos y etiquetas
  labs(
    title = "Relación entre Saltos Directos y Sensibilidad al Tamaño del BTB",
    x = "Porcentaje de Saltos Directos",
    y = "Pendiente de la tendencia del IPC"
  ) +
  # Estilo visual limpio
  theme_minimal()

# Mostrar el gráfico
print(grafico)