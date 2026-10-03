import pandas as pd
import os
import glob

ruta_procesados = os.path.join('.', 'data', 'processed')
archivos_encontrados = glob.glob(os.path.join(ruta_procesados, '*.csv'))


for ruta_completa in archivos_encontrados:
    # Extraer nombre
    nombre_archivo = os.path.basename(ruta_completa)
    
    df = pd.read_csv(ruta_completa, nrows=5)
    print(f"\n--- {nombre_archivo} ---")
    print(list(df.columns))