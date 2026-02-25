import os
import argparse
from fpdf import FPDF

# Configuración
ANCHO_A4 = 210
ALTO_A4 = 297
MARGEN = 10
COLS = 2
FILAS = 5

# Uso
# python3 data-graphing/generate_report.py 3-graphs/all_IPC/

def crear_pdf_histogramas(directorio):
    # Comprobar que la ruta existe
    if not os.path.isdir(directorio):
        print(f"Error: La carpeta '{directorio}' no existe.")
        return

    pdf = FPDF(orientation='P', unit='mm', format='A4')
    pdf.set_auto_page_break(auto=False)
    
    # Obtener archivos PNG ordenados de la ruta proporcionada
    archivos = sorted([f for f in os.listdir(directorio) if f.lower().endswith('.png')])
    
    if not archivos:
        print(f"Aviso: No se encontraron archivos .png en la carpeta '{directorio}'.")
        return

    # Dimensiones de cada celda
    ancho_img = (ANCHO_A4 - (2 * MARGEN)) / COLS
    alto_img = (ALTO_A4 - (2 * MARGEN)) / FILAS

    # Lógica de paginación
    img_por_pag = COLS * FILAS
    
    for i, archivo in enumerate(archivos):
        # Si es el inicio de un bloque de 10, añadir página
        if i % img_por_pag == 0:
            pdf.add_page()
            
        pos_en_pagina = i % img_por_pag
        columna = pos_en_pagina % COLS
        fila = pos_en_pagina // COLS
        
        x = MARGEN + (columna * ancho_img)
        y = MARGEN + (fila * alto_img)
        
        # Necesitamos la ruta completa para que fpdf encuentre la imagen
        ruta_imagen = os.path.join(directorio, archivo)
        
        # Insertar imagen
        try:
            pdf.image(ruta_imagen, x=x, y=y + 2, w=ancho_img - 2, h=alto_img - 5)
            
            # Escribir el nombre del archivo encima
            pdf.set_xy(x, y)
            pdf.set_font("Arial", size=8)
            pdf.cell(ancho_img, 5, align='C')
            
        except Exception as e:
            print(f"Error procesando {archivo}: {e}")

    # Guardar el PDF resultante dentro de la misma carpeta de las gráficas
    ruta_salida = os.path.join(directorio, "Reporte_Histogramas.pdf")
    pdf.output(ruta_salida)
    print(f"¡Éxito! Se procesaron {len(archivos)} imágenes.")
    print(f"El PDF se ha guardado en: {ruta_salida}")

if __name__ == "__main__":
    # Configurar el analizador de argumentos
    parser = argparse.ArgumentParser(description="Genera un PDF con 10 gráficas por página a partir de una carpeta.")
    parser.add_argument("ruta", help="Ruta de la carpeta que contiene las gráficas en .png")
    
    # Leer los argumentos pasados en la consola
    args = parser.parse_args()
    
    # Llamar a la función con la ruta proporcionada
    crear_pdf_histogramas(args.ruta)