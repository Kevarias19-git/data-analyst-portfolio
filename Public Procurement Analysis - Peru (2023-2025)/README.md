# Public Procurement Analysis - Peru (2023-2025)

For this project, I analyzed about 6.9 million records of Peru's public procurement data using SQLite and Power BI, built from the government's open contracting data (OCDS standard). I designed a relational schema with surrogate keys across six entities (processes, awards, contracts, suppliers, tenderers and parties), audited referential integrity and data quality (orphan contracts, unreported reference amounts, unreliable currency conversions and duplicate processes across OCID families), and built 23 SQL views (currency normalization, fact tables, dimensions, window function rankings, market concentration metrics and a data quality summary) to feed a five-page Power BI report with a star schema and 30+ DAX measures.

**Tools:** SQLite, SQL, Python (pandas), Power BI, DAX

**Skills:** Data modeling, Surrogate key design, SQL (CTEs, window functions, JOINs, aggregation), Data cleaning and type validation with Python/pandas, Referential integrity and data quality auditing, Currency normalization, Star schema design, DAX measures and Power BI dashboard design.

**Outputs:**

- Detailed SQL scripts for schema creation and 23 analytical views, in `.sql` format.
- Python/Jupyter notebook documenting the full ETL pipeline (extraction, cleaning, type validation, surrogate key construction) with in-line comments, in `.ipynb` format.
- Power BI report with five pages (summary, suppliers, entities and geography, competition and category, data quality), in `.pbix` format.

&nbsp;
## Dashboards

**Summary**: Executive KPIs (processes, reference and awarded amounts, award rate, net difference vs. reference, single-bidder rate), awarded vs. reference amount by year, a waterfall from the reference amount to the awarded amount, the top 10 procuring entities and the awarded amount by procurement category.
![Summary](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-summary.jpg)
*Across 2023-2025, 236,234 processes had a reference amount of S/ 384.90bn and S/ 248.72bn was awarded (78.3% of processes were awarded). Among awarded processes with a reported reference, the awarded amount was 5.0% below the reference. 51,254 processes (S/ 129bn of reference) were not awarded.*


**Suppliers**: Top 10 suppliers by awarded amount, supplier concentration by year, supplier size (number of awards vs. awarded amount) and the top 10 suppliers by procurement category.
![Suppliers](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-suppliers.jpg)
*86,088 suppliers won awards. Viettel Perú leads with S/ 1.25bn, followed by Rimac Seguros and J Y S Servicios Generales (S/ 1.11bn each), but the top 10 suppliers hold only 3.88% of the awarded amount. 1.92% of awards have no supplier recorded.*


**Entities & Geography**: KPIs for 2,996 procuring entities, a department bubble chart (award rate vs. net difference), a department scorecard, the top 15 entities by number of processes and the entities with the lowest award rate.
![Entities and Geography](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-entities-geography.jpg)
*Lima concentrates 52% of the awarded amount (S/ 129.24bn) and the top 5 entities account for 17.2%. Seguro Social de Salud has the most processes (5.6K). Among entities with 100+ processes, the lowest award rate is 39.8%.*


**Competition & Category**: Single-bidder and low-competition rates by procurement method, year and category, the entities with the highest single-bidder rate and the distribution of the number of bidders per process.
![Competition and Category](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-competition-category.jpg)
*26,607 processes (12.4% of those with bidder data) had a single bidder. The rate is 88.9% in direct procurement, 20.8% in selective and 8.3% in open procedures, and it is highest in services (about 19-22%). The median process has 9 bidders.*


**Data Quality**: Summary of 15 data findings with counts, rates and amounts, plus the reference amounts not reported by method and year, contract coverage and orphan contracts by year.
![Data Quality](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-data-quality.jpg)
*16,161 processes (6.84%) have no reference amount, 21,925 awards (10.77%) have no contract, 1,933 contracts (0.98%) are orphans and 664 processes use an estimated exchange rate. They are documented as known data limitations, not cleaning errors.*

&nbsp;
## Tables

- `records` - one row per contracting process (2023-2025)
  - Fields: 22
  - Records: 236,234
- `awards` - award data per process
  - Fields: 7
  - Records: 203,498
- `contracts` - signed contracts, linked to their award
  - Fields: 16
  - Records: 196,827
- `parties` - buyers, suppliers and tenderers catalog
  - Fields: 14
  - Records: 3,143,082
- `awa_suppliers` - winning supplier per award
  - Fields: 7
  - Records: 199,581
- `ten_tenderers` - all tenderers (winning or not) per process
  - Fields: 6
  - Records: 2,906,843


&nbsp;
## Methodology

- **Data model:** the SQL views feed a star schema in Power BI, with two fact tables (processes and awards) and dimensions for supplier, entity, category, method, department and year.
- **Currency:** all amounts are expressed in soles (PEN). Where the source conversion is valid it is used as is. Otherwise, the views estimate an implied exchange rate per currency (same process, then month, year or all-years average) and discard rates more than 15% away from the yearly average. Each process is flagged with its method (`not_needed`, `source`, `estimated`, `missing`), and 664 processes use an estimated rate.
- **Net difference vs. reference:** calculated as a ratio of sums, only for awarded processes with a reported reference amount. It is not presented as savings, because the reference amount is not necessarily a budget.
- **Competition:** single-bidder and low-competition (1-2 bidders) rates use only the 215,041 processes (91.03%) with tenderer data.
- **Duplicates:** processes that look duplicated across OCID families are flagged (15,047 processes), not removed, and totals include them.

&nbsp;
## Data limitations

- 1,933 contracts (0.98%) reference awards that do not exist in the source files. They are kept and flagged, not removed.
- The field `tender_value_amount_pen` (reference amount converted to soles) is unreliable: it is zero in about 6,600 processes (2.8%) even though the original amount is positive, and 18 converted values were outliers. These cases are handled with the estimated exchange rate described above.
- 16,161 processes (6.84%) have no reference amount, so they are excluded from the net difference and shown separately (S/ 5.35bn awarded without a reference). The cause could not be verified.
- 51,254 processes (21.7%) have no award, and 21,925 awards (10.77%) have no contract. Causes were not verified.
- Tender duration is not usable: it is zero or missing in practically all processes.
- 6,920 processes (3.2%) report more than 50 tenderers. They are kept as reported and not verified.

&nbsp;
## Acknowledgements

The data is sourced from Peru's public procurement open data portal, published by OECE (Organismo Especializado para las Contrataciones Eficientes y Transparentes) under the Open Contracting Data Standard, available at the [OECE - Contrataciones Abiertas](https://contratacionesabiertas.oece.gob.pe/descargas) (Open Contracting Data Standard)
