# Pizza Sales Data Vault DWH

An academic PostgreSQL and dbt warehouse project built on the Pizza Sales sample dataset. It combines Bronze/Silver/Gold layers with a Raw Data Vault to preserve changes observed across successive loads, then exposes a current-state analytical view. The CSV files are static snapshots: hashdiff-based comparisons detect payload changes between loads without source CDC. The sections below cover model grain, loading behavior, setup, and tests.

## 🎯 What This Project Demonstrates

- Layered dbt and PostgreSQL warehouse design, with Bronze/Silver/Gold organization kept distinct from Data Vault modelling.
- Raw Data Vault Hubs, a Link, and historized Satellites.
- Deterministic MD5 hash keys and hashdiff-based payload change detection, with hashes stored as 16-byte PostgreSQL `BYTEA` values.
- Incremental historical loading that preserves previously observed Satellite versions.
- Layered source, staging, Raw Vault, and Gold data-quality contracts with dbt tests.
- A current-state analytical OBT with explicit price, timestamp, and temporal assumptions.

## Project Context

This project was developed as part of a university Database Technologies course. I implemented the assignment with additional engineering depth and brought the repository to portfolio quality through reproducible setup, layered data-quality contracts, systematic validation, Git-based development, and detailed technical documentation.

## 📖 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Data Vault Model and Grain](#data-vault-model-and-grain)
- [Historical Loading](#historical-loading)
- [Gold / OBT Semantics](#gold-obt-semantics)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Configuration](#configuration)
- [Data Quality and Tests](#data-quality-and-tests)
- [dbt Documentation and Lineage](#dbt-documentation-and-lineage)
- [Reproducibility](#reproducibility)
- [Assumptions and Limitations](#assumptions-and-limitations)
- [Dataset and License](#dataset-and-license)
- [Kurzbeschreibung (DE)](#kurzbeschreibung-de)
- [Contact](#contact)

## Overview

The project uses four CSV datasets (`orders`, `order_details`, `pizzas`, and `pizza_types`). dbt seeds stand in for a simple ingestion step; the sample files are snapshots, not a streaming or CDC source. Data Vault 2.0 separates business identities and associations from historized descriptive context. The Gold layer currently provides one output: `obt_pizza_sales`.

## Architecture

Bronze/Silver/Gold describes the project's layer organization; Data Vault 2.0 describes the Raw Vault modelling approach. They are combined concepts with different roles.

```text
CSV files / dbt seeds
        ↓
Declared source relations
        ↓
Bronze views
        ↓
Staging views (hash keys, hashdiffs, LDTS, record source)
        ↓
Raw Data Vault (Hubs, Link, Satellites, current reference)
        ↓
Gold: current-state OBT view
```

- **Seeds** load the tracked CSV files into PostgreSQL and emulate source ingestion for this project.
- **Sources** in `models/sources.yaml` describe input relations. A source declaration does not create or load a relation.
- **Bronze** models are views over those input relations; they perform the source-facing projection and light normalization used by the project.
- **Staging** models call AutomateDV to derive hash keys, hashdiffs, `LOAD_DATETIME` and `RECORD_SOURCE`.
- **Raw Vault** contains incremental Hubs, a Link and Satellites, plus the non-historised `ref_pizza_type` reference table.
- **Gold** is the `obt_pizza_sales` current-state reporting view.

The default source location and the seed location are the same PostgreSQL database and the `<base_schema>_bronze_db` schema. The default dbt schema suffixes are `<base_schema>_bronze_db`, `<base_schema>_data_vault`, and `<base_schema>_data_marts`.

## Data Vault model and grain

- `hub_order`: one row per unique `order_id` business key.
- `hub_pizza`: one row per unique Pizza SKU (`pizza_id`) business key.
- `lnk_order_pizza`: one unique Order ↔ Pizza SKU association, hashed from `(order_id, pizza_id)`. This Link is not a transaction-line key.
- `sat_order`, `sat_pizza`, and `sat_order_pizza`: historized payload for their parent hash key, with versions distinguished by `LOAD_DATETIME`.
- `ref_pizza_type`: the current, non-historised pizza type catalog.

The current source contract requires `(order_id, pizza_id)` to be unique in `order_details`. In this dataset, pizzas of the same type and size in an order are represented by one source row and the `quantity` value increases. A source test enforces the pair uniqueness assumption because the Link key does not distinguish two rows with the same order and Pizza SKU. `order_details_id` remains source payload in the association Satellite; it is not part of the Link hash key.

## Historical loading

Raw Vault Hubs, Link, and Satellites use incremental materialization. The four staging models use dbt's `run_started_at` as a shared batch `LOAD_DATETIME` (LDTS), so rows staged by one invocation receive the same batch timestamp. Re-running unchanged seed data does not add Hub or Link records or a new Satellite version. A changed Satellite payload can add a new version while retaining the previous one.

This history records what the project loaded and when it loaded it. The CSVs do not provide source CDC events or business-effective timestamps, so this project does not claim to reconstruct source changes that were never present in the input.

<a id="gold-obt-semantics"></a>
## Gold / OBT Semantics

`obt_pizza_sales` is a current-state enrichment view with one row per `order_details_id`. It selects the latest available row from each participating Satellite; it is not a point-in-time or transaction-time historical mart. Pizza type attributes come from the current reference catalog through a `LEFT JOIN`, so a missing reference does not remove a sale row.

The `price` column is the latest available catalog price for a Pizza SKU. `total_price` is `quantity * price` using that latest price. These values are not guaranteed to represent revenue at the time of the order: the source has no separate `price_at_sale` field or business-valid price history. `order_datetime` combines the source order date and time without an asserted timezone. `record_load_datetime` is the maximum technical load timestamp among the sales-related Order, Pizza, and Order-Pizza Hub/Link/Satellite inputs; a reference catalog rebuild is excluded.

## Technology stack

Versions tested for this repository:

| Component | Version |
| --- | --- |
| CPython | 3.14.8 |
| dbt-core | 1.12.5 |
| dbt-postgres | 1.11.0 |
| AutomateDV | 0.11.5 |
| dbt_utils | 1.4.1 |
| PostgreSQL | Tested on 17.5; target major line 17.x |

## Project structure

```text
models/
  sources.yaml
  l_00_brz/             # Source-facing Bronze views
  l_10_stg/             # AutomateDV staging views and technical contracts
  l_20_data_vault/      # Raw Vault and reference model with contracts
  l_30_data_marts/      # Current-state OBT and consumer contract
seeds/
  data/                 # Four input CSVs
  meta/                 # Dataset data dictionary CSV
requirements.in         # Direct Python runtime dependencies
requirements.txt        # Generated, pinned Python dependency lock
packages.yml            # Direct dbt package dependencies
package-lock.yml        # Resolved dbt package versions
profiles.yml.example    # Credential-free dbt profile template
.python-version         # Project Python version declaration
dbt_project.yml         # dbt paths, schemas, tags, and materializations
```

The repository also contains pre-generated HTML data-profile reports and `check_data.py`. The profiling script needs optional analysis packages that are not part of the dbt runtime lock; it is not required to run the warehouse project.

## Setup

Clone this repository and run the following commands from its root directory.

### 1. Select Python

Install CPython 3.14.8, then create the environment from that interpreter. `.python-version` records the expected version; verify the interpreter before installing packages.

**Windows PowerShell**

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python --version  # Expected: Python 3.14.8
```

**Linux / macOS**

```bash
python3.14 -m venv .venv
source .venv/bin/activate
python --version  # Expected: Python 3.14.8
```

If the launcher selects another 3.14 patch release, create `.venv` with the explicit path to the installed 3.14.8 interpreter.

### 2. Install the pinned Python dependencies

```shell
python -m pip install --require-hashes -r requirements.txt
```

`requirements.in` lists the direct runtime dependencies (`dbt-core` and `dbt-postgres`). `requirements.txt` is the generated, fully pinned lock with hashes for the resolved Python dependency graph.

### 3. Configure dbt and PostgreSQL

If you do not already have a dbt profile, copy `profiles.yml.example` to the dbt user profile location. If a `profiles.yml` already exists, merge this project's profile block instead of overwriting it. Provide the required environment variables described under [Configuration](#configuration). The example contains no credentials.

```powershell
$profileDir = Join-Path $HOME ".dbt"
$profilePath = Join-Path $profileDir "profiles.yml"
New-Item -ItemType Directory -Force $profileDir | Out-Null
if (Test-Path $profilePath) {
  Write-Output "Keep the existing profile and merge the dbt_with_datavault_demo block."
} else {
  Copy-Item profiles.yml.example $profilePath
}
```

```bash
mkdir -p ~/.dbt
if [ -e ~/.dbt/profiles.yml ]; then
  printf '%s\n' "Keep the existing profile and merge the dbt_with_datavault_demo block."
else
  cp profiles.yml.example ~/.dbt/profiles.yml
fi
```

### 4. Install dbt packages and validate the connection

```shell
dbt deps
dbt debug
dbt parse --no-partial-parse
dbt compile
```

### 5. Load the demo inputs and build

On a fresh warehouse, load the seeds before building models: `sources.yaml` declares the relations but does not create a dependency edge from those source relations to the seed nodes.

```shell
dbt seed
dbt build --exclude-resource-type seed
```

The seed command loads the CSV files, including the data dictionary. The build command then builds models and their tests without reloading the seeds. For later runs, repeat `dbt build --exclude-resource-type seed` when the source seed tables are already present. Layer-scoped selections assume their upstream relations have already been built. The configured tags can be selected:

```shell
dbt build --select tag:raw_vault --exclude-resource-type seed
dbt build --select tag:marts --exclude-resource-type seed
```

Other useful commands:

```shell
dbt run
dbt test
dbt docs generate
dbt docs serve
```

## Configuration

`profiles.yml.example` uses profile name `dbt_with_datavault_demo`.

| Variable | Required | Purpose |
| --- | --- | --- |
| `DBT_PG_DATABASE` | Yes | PostgreSQL database for the dbt target |
| `DBT_PG_SCHEMA` | Yes | Base schema name; dbt appends the project layer suffix |
| `DBT_PG_USER` | Yes | PostgreSQL user |
| `DBT_PG_PASSWORD` | Yes | PostgreSQL password; do not commit it or place it in the example file |
| `DBT_PG_HOST` | No | Host; defaults to `localhost` |
| `DBT_PG_PORT` | No | Port; defaults to `5432` |
| `DBT_SOURCE_DATABASE` | No | Source database; defaults to the target database |
| `DBT_SOURCE_SCHEMA` | No | Source schema; defaults to `<DBT_PG_SCHEMA>_bronze_db` |

Keep source and target in the same PostgreSQL database for the default design. PostgreSQL does not provide arbitrary cross-database table joins; a separate source database must first be exposed to the target database through an appropriate database-side mechanism. The source schema can be overridden independently when the input relations are in a different schema of the same database.

## Data quality and tests

Contracts are layered around input validity and persisted model integrity:

- **Source** tests cover source identities, required relationships, and uniqueness of `(order_id, pizza_id)`.
- **Staging** tests check non-null generated hash keys, hashdiffs, load timestamps, and record-source metadata.
- **Raw Vault** tests cover Hub/Link hash-key integrity, parent relationships, Satellite `(parent_hash_key, LOAD_DATETIME)` grain, and selected required payload fields. Descriptive fields that may be absent remain nullable.
- **Gold** tests enforce one row per `order_details_id` and required consumer-facing values; reference-derived descriptions remain nullable.

Run `dbt test` after the input seeds and models have been built.

## dbt Documentation and Lineage

The project includes dbt-native documentation generated from model and column descriptions, source definitions, tests, and project dependencies.

Generate and open the local documentation site with:

```shell
dbt docs generate
dbt docs serve
```

The generated site provides searchable model and column metadata, associated data tests, and an interactive lineage graph showing the dependency flow from source relations through Bronze, Staging, Raw Vault, and the Gold OBT.

Generated documentation artifacts are written to `target/` and are intentionally not version-controlled.

## Reproducibility

- `.python-version` declares CPython 3.14.8.
- `requirements.in` records direct Python dependencies; `requirements.txt` is the generated exact, hash-pinned Python lock.
- `packages.yml` declares direct dbt packages; tracked `package-lock.yml` records their resolved versions.
- `.venv/`, `dbt_packages/`, `target/`, and `logs/` are local or generated artifacts and are intentionally ignored by Git.
- The real `profiles.yml` and `.env` are local secrets/configuration and must not be committed. `profiles.yml.example` is the safe tracked template.

## Assumptions and limitations

- dbt seeds emulate ingestion; this is a static sample dataset, not a streaming or CDC source.
- The `(order_id, pizza_id)` association grain depends on the current source uniqueness contract.
- Raw Vault LDTS is a batch load timestamp, not source event time or business-valid time.
- Gold `obt_pizza_sales` enriches sales with the latest available descriptive state and catalog price; it is not an as-of revenue fact.
- A multidimensional Star Schema is a possible future extension; it is not part of the current implementation.

## Dataset and License

This project uses the **Pizza Place Sales** sample dataset available through the [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground/pizza-place-sales). Maven Analytics credits the dataset to Vincent Arel-Bundock (Rdatasets) and lists its license as Public Domain.

The MIT License in this repository applies to the project code and documentation.

<a id="kurzbeschreibung-de"></a>
## 🇩🇪 Kurzbeschreibung

Dieses akademische Data-Warehouse-Projekt entstand im Rahmen des Hochschulkurses Datenbanktechnologien. Es verbindet PostgreSQL, dbt und Data Vault 2.0 in einer mehrschichtigen Warehouse-Architektur mit historisierten Raw-Vault-Strukturen und automatisierten Datenqualitätstests. Das Repository wurde durch reproduzierbares Setup, technische Dokumentation und systematische Validierung portfoliofähig aufbereitet. Die Gold-Ansicht stellt einen aktuell angereicherten Datenstand dar und bildet keine historisch gültigen Transaktionspreise ab.

<a id="contact"></a>
## 📬 Contact

- **GitHub:** [@yevhenii-miroshnikov](https://github.com/yevhenii-miroshnikov)
- **LinkedIn:** [yevhenii-miroshnikov](https://www.linkedin.com/in/yevhenii-miroshnikov)
