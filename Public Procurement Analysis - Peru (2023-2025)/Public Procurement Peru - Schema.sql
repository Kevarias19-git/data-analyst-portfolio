--  Open Contracts (OCDS) Peru, 2023-2025

-- records [1] ---> [*] com_parties (via ocid)
-- records [1] ---> [*] com_ten_tenderers (via ocid)
-- records [1] ---> [*] com_awards (via ocid)
--    com_awards [1] ---> [*] com_contracts (via award_key)
--    com_awards [1] ---> [*] com_awa_suppliers (via award_key)


CREATE TABLE "records" (
    "ocid" TEXT PRIMARY KEY NOT NULL,
    "release_date" TEXT,
    "buyer_id" TEXT,
    "buyer_name" TEXT,
    "budget_amount" REAL,
    "tender_id" TEXT,
    "tender_title" TEXT,
    "procuring_entity_id" TEXT,
    "procuring_entity_name" TEXT,
    "tender_published_date" TEXT,
    "procurement_method" TEXT,
    "procurement_category" TEXT,
    "tender_value_amount" REAL,
    "tender_value_currency" TEXT,
    "tender_value_amount_pen" REAL,
    "number_of_tenderers" INTEGER,
    "tender_start_date" TEXT,
    "tender_end_date" TEXT,
    "tender_duration_days" INTEGER,
    "tender_year" INTEGER,
    "invalid_period" INTEGER,
    "year" INTEGER
);

CREATE TABLE "parties" (
    "party_key" TEXT PRIMARY KEY NOT NULL,
    "ocid" TEXT,
    "party_id" TEXT,
    "party_name" TEXT,
    "identifier_id" TEXT,
    "identifier_scheme" TEXT,
    "roles" TEXT,
    "is_buyer" INTEGER,
    "is_procuringentity" INTEGER,
    "is_supplier" INTEGER,
    "is_tenderer" INTEGER,
    "region" TEXT,
    "department" TEXT,
    "year" INTEGER,
    FOREIGN KEY ("ocid") REFERENCES "records" ("ocid")
);

CREATE TABLE "ten_tenderers" (
    "tenderer_key" TEXT PRIMARY KEY NOT NULL,
    "ocid" TEXT,
    "tender_id" TEXT,
    "tenderer_id" TEXT,
    "tenderer_name" TEXT,
    "year" INTEGER,
    FOREIGN KEY ("ocid") REFERENCES "records" ("ocid")
);

CREATE TABLE "awards" (
    "award_key" TEXT PRIMARY KEY NOT NULL,
    "ocid" TEXT,
    "award_id" TEXT,
    "award_amount" REAL,
    "award_currency" TEXT,
    "award_date" TEXT,
    "year" INTEGER,
    FOREIGN KEY ("ocid") REFERENCES "records" ("ocid")
);

CREATE TABLE "contracts" (
    "contract_key" TEXT PRIMARY KEY NOT NULL,
    "award_key" TEXT,
    "ocid" TEXT,
    "contract_id" TEXT,
    "award_id" TEXT,
    "contract_title" TEXT,
    "contract_amount" REAL,
    "final_value_amount" REAL,
    "amount_variance" REAL,
    "date_signed" TEXT,
    "period_start_date" TEXT,
    "period_end_date" TEXT,
    "period_days" INTEGER,
    "invalid_period" INTEGER,
    "year" INTEGER,
    "award_in_awards" INTEGER,
    FOREIGN KEY ("award_key") REFERENCES "awards" ("award_key")
);

CREATE TABLE "awa_suppliers" (
    "supplier_key" TEXT PRIMARY KEY NOT NULL,
    "award_key" TEXT,
    "ocid" TEXT,
    "award_id" TEXT,
    "supplier_id" TEXT,
    "supplier_name" TEXT,
    "year" INTEGER,
    FOREIGN KEY ("award_key") REFERENCES "awards" ("award_key")
);

-- Indexes on FK columns (PKs already have an automatic unique index)
CREATE INDEX IF NOT EXISTS ix_parties_ocid ON "parties"("ocid");
CREATE INDEX IF NOT EXISTS ix_ten_tenderers_ocid ON "ten_tenderers"("ocid");
CREATE INDEX IF NOT EXISTS ix_awards_ocid ON "awards"("ocid");
CREATE INDEX IF NOT EXISTS ix_contracts_award_key ON "contracts"("award_key");
CREATE INDEX IF NOT EXISTS ix_awa_suppliers_award_key ON "awa_suppliers"("award_key");