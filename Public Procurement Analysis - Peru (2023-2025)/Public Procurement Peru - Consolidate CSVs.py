import os
import glob
import pandas as pd

# Path configuration
BASE_DIR = '.'
RAW_DIR = os.path.join(BASE_DIR, 'data', 'raw')
PROCESSED_DIR = os.path.join(BASE_DIR, 'data', 'processed')

# Core OCDS tables to process
CATEGORIES = [
    'com_awa_suppliers',
    'com_awards',
    'com_contracts',
    'com_parties',
    'com_ten_tenderers',
    'records'
]
YEARS = ['2023', '2024', '2025']

# This field was added in late 2025. Dropped globally so it doesn't break
# the concatenation with historical months that don't have it.
IGNORED_COLUMN = 'compiledRelease/tender/tenderPeriod/durationInDays'


def audit_2025_contracts():  # quick audit of 2025 contracts
    """Prints the column count for each 2025 contracts file, for a quick check."""
    print(" --- Quick audit: 2025 contracts ---")

    files = glob.glob(os.path.join(RAW_DIR, '2025', '*', 'com_contracts.csv'))
    files.sort(key=lambda x: int(os.path.basename(os.path.dirname(x))))  # sort by month

    for file in files:
        month = os.path.basename(os.path.dirname(file))
        columns = pd.read_csv(file, nrows=0).columns
        print(f"[Month {int(month):02d}] Columns found: {len(columns)}")
    print("-" * 40 + "\n")


def consolidate_historical_data():
    """Validates the structure of the monthly CSVs and consolidates them into yearly files."""
    for year in YEARS:
        print(f"> Processing {year} data...")

        for category in CATEGORIES:
            files = glob.glob(os.path.join(RAW_DIR, year, '*', f'{category}.csv'))
            files.sort(key=lambda x: int(os.path.basename(os.path.dirname(x))))  # sort by month

            if not files:
                continue

            # Structure validation (headers)
            reference_columns = None
            valid_structure = True

            for file in files:
                # read header and drop the conflicting column
                header_df = pd.read_csv(file, nrows=0).drop(columns=[IGNORED_COLUMN], errors='ignore')
                current_columns = set(header_df.columns)

                if reference_columns is None:
                    reference_columns = current_columns
                elif reference_columns != current_columns:
                    print(f"Broken structure in: {file}")
                    print(f"Difference: {reference_columns.symmetric_difference(current_columns)}")
                    valid_structure = False
                    break

            if not valid_structure:
                print(f"Skipping {category} ({year}) due to inconsistencies in the source.")
                continue

            # Bulk concatenation
            try:
                # drop the ignored column
                final_df = pd.concat(
                    (pd.read_csv(f, low_memory=False).drop(columns=[IGNORED_COLUMN], errors='ignore') for f in files),
                    ignore_index=True
                )

                output_path = os.path.join(PROCESSED_DIR, f'{category}_{year}_completo.csv')
                final_df.to_csv(output_path, index=False)

                print(f"[OK] {category}_{year} merged. Shape: {final_df.shape}")

            except Exception as e:
                print(f"[ERROR] Failed to consolidate {category} ({year}): {e}")


if __name__ == '__main__':
    # create the output directory if it doesn't exist
    os.makedirs(PROCESSED_DIR, exist_ok=True)

    audit_2025_contracts()
    consolidate_historical_data()

    print("\nData pipeline finished.")