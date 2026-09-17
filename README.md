# Olist E-commerce Pipeline

## Introduction 
This project builds an end-to-end data and analytics pipeline using the Olist Brazilian E-Commerce Public Dataset. The objective is to demonstrate how raw, multi-table e-commerce data can be transformed into reliable, analytics-ready datasets and used to identify a clear commercial opportunity. The solution is built on the Databricks Lakehouse using a medallion architecture. Raw source data is ingested into a Bronze layer, cleaned and conformed into a normalised Silver layer, and then transformed into a denormalised Gold star schema for analytical workloads.

Beyond the engineering pipeline, the project focuses on turning the resulting data into actionable business insight. The analysis examines customer and transaction behaviour to identify commercially meaningful patterns and translates these findings into a specific campaign recommendation, including a target segment, expected impact and measurement approach.

Olist was selected because its multi-table structure provides a realistic data engineering challenge, with linked customers, orders, order items, products, sellers, payments, reviews and geographic data. This makes it possible to demonstrate both data modelling and the ability to connect technical outputs to practical commercial decisions.

The project is version controlled in GitHub and is designed to be reproducible, with documented assumptions, data quality considerations and instructions for running the pipeline.

## Data Sources
This project uses the Olist Brazilian E-Commerce Public Dataset, a publicly available dataset containing information from approximately 100,000 orders made between 2016 and 2018 on the Olist marketplace in Brazil.

The dataset consists of multiple CSV files representing different business entities and processes, including:

- **customers** - customer identifiers, location and postcode information
- **orders** - order status and purchase, approval, delivery and estimated delivery timestamps
- **order_items** - products purchased, sellers, prices and freight values
- **products** - product identifiers, categories and physical characteristics
- **sellers** - seller identifiers and geographic information
- **payments** - payment methods, instalments and transaction values
- **reviews** - customer review scores and review comments
- **geolocation** - Brazilian postcode prefixes and associated latitude/longitude coordinates
- **category_translation** - Portuguese product categories translated into English

### Why this dataset 

I chose the **Olist Brazilian E-Commerce Public Dataset** because its structure closely reflects the type of real world data environment found in consumer businesses. The dataset contains multiple interconnected entities such as customers, orders, products, sellers, payments, reviews and geographic information.

This makes it well suited to demonstrating the full data lifecycle required for this project. It provides complexity to build a meaningful pipeline with the **Bronze → Silver → Gold medallion architecture**, while also requiring careful decisions around data types, data quality, keys and relationships.

The dataset also provides a strong foundation for the commercial side of the assessment. Customer purchasing behaviour, order values, product performance, reviews and geography can be combined to identify commercially relevant patterns and translate them into a specific, measurable business recommendation.

## Databricks Setup

**Prerequisites before running anything:**
- A Kaggle API token, stored in Databricks Secrets under scope kaggle, key api_token. Set up once via the Databricks CLI:
```
  databricks secrets create-scope kaggle
  databricks secrets put-secret kaggle api_token
```

**Initial project structure in Databricks**
```text
e_commerce_pipeline/
├── ingest/
├── pipeline/
├── sql/
├── .gitignore
└── README.md
```

Item  | Value
------------- | -------------
Edition  | Databricks Free Edition
Compute  | Serverless
Catalog  | olist
Schemas  | olist.bronze, olist.silver, olist.gold
Volume  | /Volumes/olist/bronze/raw_data

**How to run**
1. **Create the catalog, schemas, and volume:**
- Run /pipeline/01_create_tables.sql
- Creates the olist catalog, the three medallion schemas, and the volume used to stage raw files. Safe to re-run (uses IF NOT EXISTS).

2. **Ingest raw data into bronze:**
- Run /ingest/load_bronze
- Authenticates with Kaggle (via Databricks Secrets), downloads the dataset into the volume, reads all 9 CSVs, and writes each one into a bronze Delta table. No cleaning applied at this stage as bronze lands the raw source.

3. **Build the silver layer:**
- Run /pipeline/02_bronze_to_silver
- For each table: deduplicates on its natural key, generates a surrogate key and casts datatypes correctly (text → TIMESTAMP where needed), and adds _loaded_at / _source metadata columns. Ends by applying NOT NULL constraints to each table's key column.

4. **Build the gold layer:**
- Run /pipeline/03_silver_to_gold
- Builds three dimensions (dim_customer, dim_product, dim_seller) and one fact table (fact_order_items, at one row per order line item). Payments are aggregated to one row per order before joining, to avoid multiplying line items.

5. **Run the analytics queries:**
- Open /sql/analytics_queries.sql in a SQL notebook or the Databricks SQL editor and run each query block against the gold layer.

**Metrics**

1. Top 10 peoducts by total revenue
2. Monthly revenue trend across the full dataset
3. Products priced above the 95th percentile - flagging unusually high value items for further investigation 
4. Revenue and order count by customer state
5. What is our current month-to-date revenue and how does it compare to the same point in the previous month?


## Repository setup - GitHub

This repository is connected to the Databricks workspace through Git folders (Repos). This allows notebooks to be created and edited directly in Databricks and committed to the repository. The project contains both Databricks notebooks and source files such as `.py` and `.sql`, allowing the work to be tracked and reviewed through version control. Work was done on feature branches with pull requests into main.

```text
├── ingest/
│   └── load_bronze                    # Raw data ingestion / Bronze layer
├── pipeline/                          # Data transformation and modelling
│   └── 01_create_tables.sql           
│   └── 02_bronze_to_silver            # Silver 3NF data model
│   └── 03_silver_to_gold
│   └── data_model.md
├── sql/                               # Gold layer and analytical SQL
│   └── analytics_queries.sql
├── analysis_answers.md                # Commercial insights      
├── README.md                          # Project overview and setup instructions
├── requirements.txt
└── .gitignore                         
```

## Assumptions and Shortcuts

**Data assumptions:**
- Timestamps converted assuming UTC - the raw data doesn't document its original timezone (likely Brazil local time). Since all analysis is relative (trends, comparisons), this doesn't materially affect conclusions.
- Revenue defined as price (item price) rather than total_payment_value, since the latter includes freight and installment effects.
casa_conforto and casa_conforto_2 kept as distinct categories - Olist's own translation table treats them as separate entries, so merging would have been an unverified assumption.
- Orders marked canceled that still carry a delivery date were left as-is rather than "corrected" or "returned" - it's unclear whether they were delivered then canceled, or the status was updated without clearing the date.
- Known data quality issues (a numeric value in seller_city, CSV parsing corruption affecting some review rows) are documented rather than silently fixed. One review row with a fully null review_id was removed, as it couldn't be joined or deduplicated.

**Shortcuts given the time-box:**
- Constraints are limited to NOT NULL on key columns. No primary/foreign key declarations or Delta CHECK constraints were added beyond this.
- The gold layer covers three dimensions and one fact table; reviews and geolocation weren't given their own gold tables, as their useful attributes were either absorbed into dimensions or not needed for the analysis.
- The commercial impact estimate in analysis_answers.md is an illustrative, assumption-stated figure. A real campaign would need a pilot to confirm conversion rates.


