#!/bin/bash

# --- Configuración ---
# Directorio raíz donde están los trabajos (según tu imagen)
JOBS_DIR="1-output-jobs"
# Nombre de tu script original (asegúrate de que esté en la misma carpeta)
PARSER_SCRIPT="./data-parsing/simple_parser.sh"

# --- Verificaciones iniciales ---
if [ ! -d "$JOBS_DIR" ]; then
    echo "Error: No encuentro el directorio '$JOBS_DIR' en la ruta actual."
    exit 1
fi

if [ ! -f "$PARSER_SCRIPT" ]; then
    echo "Error: No encuentro el script '$PARSER_SCRIPT'. Asegúrate de que esté en esta carpeta."
    exit 1
fi

# Hacer ejecutable el parser original por si acaso
chmod +x "$PARSER_SCRIPT"

echo "========================================================"
echo "Iniciando procesamiento masivo de resultados"
echo "Directorio base: $JOBS_DIR"
echo "========================================================"

# --- Bucle Principal ---

# 1. Iterar sobre las configuraciones de CPU (Nivel 1: BigO3, CVA6, MediumSonicBOOM...)
for core_dir in "$JOBS_DIR"/*; do
    if [ -d "$core_dir" ]; then
        core_name=$(basename "$core_dir")
        
        # 2. Iterar sobre los Predictores de Salto (Nivel 2: LocalBP, TAGE_L, etc.)
        for bp_dir in "$core_dir"/*; do
            if [ -d "$bp_dir" ]; then
                bp_name=$(basename "$bp_dir")
                
                # VERIFICACIÓN CLAVE:
                # El parser original asume que dentro de esta carpeta existe "SPEC17".
                # Solo ejecutamos el parser si existe SPEC17 dentro.
                if [ -d "$bp_dir/SPEC17" ]; then
                    
                    # Construimos el argumento tal como lo pide tu script original.
                    # Ejemplo: 1-output-jobs/MediumSonicBOOM/TAGE_SC_L
                    target_arg="$JOBS_DIR/$core_name/$bp_name"
                    
                    echo ">> Procesando: $core_name / $bp_name"
                    
                    # Llamada al script original
                    $PARSER_SCRIPT "$target_arg"
                    
                else
                    echo "Saltando $core_name/$bp_name (No se encontró carpeta SPEC17)"
                fi
            fi
        done
    fi
done

echo "========================================================"
echo "Procesamiento masivo finalizado."
echo "========================================================"