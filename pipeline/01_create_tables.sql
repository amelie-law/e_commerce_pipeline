-- Create the schemas for each medallion layer of the pipeline
CREATE CATALOG IF NOT EXISTS olist;
CREATE SCHEMA IF NOT EXISTS olist.bronze;
CREATE SCHEMA IF NOT EXISTS olist.silver;
CREATE SCHEMA IF NOT EXISTS olist.gold;
