import os
import glob
import pandas as pd

# Configuración de rutas
BASE_DIR = '.' 
RAW_DIR = os.path.join(BASE_DIR, 'data', 'raw')
PROCESSED_DIR = os.path.join(BASE_DIR, 'data', 'processed')

# Tablas core de OCDS a procesar
CATEGORIAS = [
    'com_awa_suppliers', 
    'com_awards', 
    'com_contracts', 
    'com_parties', 
    'com_ten_tenderers', 
    'records'
]
ANIOS = ['2023', '2024', '2025']

# Esta métrica se añadió a finales de 2025. Se ignora globalmente para no romper la unión con los meses históricos que no la poseen
COLUMNA_IGNORADA = 'compiledRelease/tender/tenderPeriod/durationInDays'


def auditar_contratos_2025(): # Auditoría rápida de los contratos de 2025
    """Imprime el conteo de columnas de los contratos de 2025 para revisión rápida"""
    print(" --- Auditoría rápida: Contratos 2025 ---")
    
    archivos = glob.glob(os.path.join(RAW_DIR, '2025', '*', 'com_contracts.csv'))
    archivos.sort(key=lambda x: int(os.path.basename(os.path.dirname(x)))) #Ordena por mes
    
    for arch in archivos:
        mes = os.path.basename(os.path.dirname(arch))
        cols = pd.read_csv(arch, nrows=0).columns
        print(f"[Mes {int(mes):02d}] Columnas detectadas: {len(cols)}")
    print("-" * 40 + "\n")


def consolidar_historico():
    """Valida la estructura de los CSV mensuales y los consolida en archivos anuales."""
    for anio in ANIOS:
        print(f"> Procesando data del {anio}...")
        
        for cat in CATEGORIAS:
            archivos = glob.glob(os.path.join(RAW_DIR, anio, '*', f'{cat}.csv'))
            archivos.sort(key=lambda x: int(os.path.basename(os.path.dirname(x)))) #Ordena por mes
            
            if not archivos:
                continue
                
            # Validación de estructura (Heads)
            cols_referencia = None
            estructura_valida = True
            
            for arch in archivos:
                # Lee heads y limpia la columna conflictiva
                df_header = pd.read_csv(arch, nrows=0).drop(columns=[COLUMNA_IGNORADA], errors='ignore')
                cols_actuales = set(df_header.columns)
                
                if cols_referencia is None:
                    cols_referencia = cols_actuales
                elif cols_referencia != cols_actuales:
                    print(f"Estructura rota en: {arch}")
                    print(f"Diferencia: {cols_referencia.symmetric_difference(cols_actuales)}")
                    estructura_valida = False
                    break 
                    
            if not estructura_valida:
                print(f"Omitiendo {cat} ({anio}) por inconsistencias en origen.")
                continue
                
            # Concatenación masiva
            try:
                # Descarte de columna ignorada
                df_final = pd.concat(
                    (pd.read_csv(f, low_memory=False).drop(columns=[COLUMNA_IGNORADA], errors='ignore') for f in archivos), 
                    ignore_index=True
                )
                
                ruta_salida = os.path.join(PROCESSED_DIR, f'{cat}_{anio}_completo.csv')
                df_final.to_csv(ruta_salida, index=False)
                
                print(f"[OK] {cat}_{anio} unificado. Dimensiones: {df_final.shape}")
                
            except Exception as e:
                print(f"[ERROR] Falló la consolidación de {cat} ({anio}): {e}")


if __name__ == '__main__':
    # Creación del directorio de salida en caso no exista
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    
    auditar_contratos_2025()
    consolidar_historico()
    
    print("\nPipeline de datos finalizado.")