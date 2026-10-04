import pandas as pd
import os
import glob

processed_path = os.path.join('.', 'data', 'processed')
found_files = glob.glob(os.path.join(processed_path, '*.csv'))


for file_path in found_files:
    # extract file name
    file_name = os.path.basename(file_path)

    df = pd.read_csv(file_path, nrows=5)
    print(f"\n--- {file_name} ---")
    print(list(df.columns))