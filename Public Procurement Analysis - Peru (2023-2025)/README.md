# Public Procurement Analysis - Peru (2023-2025)

For this project, I analyzed over 6 million records of Peru's public procurement process using SQLite and Power BI, built from the government's open contracting data (OCDS standard). I designed a relational schema with surrogate keys across six entities (processes, awards, contracts, suppliers, tenderers and parties), audited referential integrity to uncover that roughly 1% of contracts reference awards that don't exist in the dataset, and built eleven SQL views, including window function rankings and market concentration metrics, to power an executive dashboard covering top entities, top suppliers, low-competition processes, and contract value variance.

**Tools:** SQLite, SQL, Python (pandas), Power BI

**Skills:** Data modeling, Surrogate key design, SQL (CTEs, window functions, JOINs, aggregation), Data cleaning and type validation with Python/pandas, Referential integrity auditing and Power BI dashboard design.

**Outputs:**

- Detailed SQL scripts for schema creation and eleven analytical views, in `.sql` format.
- Python/Jupyter notebook documenting the full ETL pipeline (extraction, cleaning, type validation, surrogate key construction) with in-line comments, in `.ipynb` format.
- Power BI dashboard covering top entities, top suppliers, low-competition processes, and contract value variance, in `.pbix` format.


## Dashboards

**Summary** — Executive KPIs (total awarded amount vs. reference budget, average tenderers, total processes), the execution trend by year, and reference budget broken down by procurement category.
![Summary](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-summary.jpg)
*Awarded spending reached S/ 82.18bn against a S/ 148.98bn reference budget across 236K processes (2023-2025).*

**Suppliers** — Top 10 suppliers by awarded amount, the year-over-year evolution of the top 5 suppliers, and each supplier's market share within its procurement category.
![Suppliers](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-suppliers.jpg)
*Sinohydro Corporation and Consorcio San Juan lead the ranking, with a sharp concentration shift visible starting 2025.*

**Entities & Geography** — Top contracting entities by awarded amount, plus a regional map and table showing processes and total amount by department.
![Entities and Geography](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-entities-geography.jpg)
*MTC's transport infrastructure program and EsSalud top the list of contracting entities. Trujillo (La Libertad) leads by volume and amount at the province level.*

**Competition & Category** — Processes by category and procurement method, with a detailed table of all low-competition processes (a single tenderer).
![Competition and Category](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-competition-category.jpg)
*26,396 processes (11% of the total) had only one tenderer, most concentrated in the "goods" category under the open procurement method.*

**Data Quality** — The orphan contracts and processes-without-award findings, with the underlying tables and a scatter plot comparing contract amount vs. final value to flag outliers.
![Data Quality](Public%20Procurement%20Peru%20-%20Dashboard%20images/dashboard-data-quality.jpg)
*1,933 orphan contracts (0.98%) and 51,254 processes without an award were identified and documented as known data limitations, not cleaning errors.*


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


## Acknowledgements
 
The data is sourced from Peru's public procurement open data portal, published by OECE (Organismo Especializado para las Contrataciones Eficientes y Transparentes) under the Open Contracting Data Standard, available at the [OECE — Contrataciones Abiertas](https://contratacionesabiertas.oece.gob.pe/descargas) (Open Contracting Data Standard)

