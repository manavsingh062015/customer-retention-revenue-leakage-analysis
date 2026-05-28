# Customer Retention & Revenue Leakage Analysis

## Executive Summary

This project is an end-to-end business analytics solution focused on customer retention, churn analysis, and revenue leakage identification using transactional retail data.

The objective of the project is to help businesses understand:
- which customers generate the highest revenue,
- which customer segments are at risk of churn,
- how retention impacts revenue growth,
- and how much revenue is potentially being lost due to inactive customers.

The solution combines:
- Python for data cleaning and exploratory analysis,
- SQL Server for warehouse modeling and business analysis,
- and Power BI for executive dashboards and business storytelling.

---

# Business Problem

The company observed slowing revenue growth despite increasing customer acquisition. Leadership wanted to identify:
- customer churn patterns,
- retention trends,
- repeat purchase behavior,
- and revenue leakage opportunities.

Without understanding customer retention, the business risks:
- higher acquisition costs,
- declining customer lifetime value,
- lower profitability,
- and long-term revenue stagnation.

This project addresses these challenges through data-driven analytics and interactive reporting.

---

# Project Objectives

- Analyze customer retention and churn behavior
- Identify high-value customer segments
- Measure repeat purchase trends
- Quantify revenue leakage from inactive customers
- Build RFM customer segmentation
- Perform cohort retention analysis
- Develop executive-level Power BI dashboards
- Deliver actionable business recommendations

---

# Tech Stack

| Technology | Purpose |
|---|---|
| Python | Data Cleaning & Analysis |
| Pandas | Data Transformation |
| NumPy | Numerical Operations |
| SQL Server | Data Warehouse & SQL Analytics |
| SSMS | SQL Development |
| Power BI | Dashboarding & Visualization |
| DAX | KPI Calculations |
| Jupyter Notebook | Analysis Workflow |
| GitHub | Version Control & Portfolio |

---

# Dataset Overview

The project uses the Online Retail II transactional dataset containing:
- customer purchases,
- invoice details,
- product information,
- revenue metrics,
- and country-level sales data.

## Dataset Columns

| Column | Description |
|---|---|
| Invoice | Transaction ID |
| StockCode | Product ID |
| Description | Product Description |
| Quantity | Units Purchased |
| InvoiceDate | Transaction Timestamp |
| Price | Unit Price |
| CustomerID | Unique Customer ID |
| Country | Customer Country |

---

# Project Workflow

## 1. Data Cleaning (Python)

Performed:
- null value handling,
- duplicate removal,
- cancelled order filtering,
- negative quantity removal,
- feature engineering.

### Features Created
- Revenue
- Order Month
- Days Since Purchase

---

## 2. SQL Data Warehouse

Designed a star schema warehouse consisting of:

### Fact Table
- FactSales

### Dimension Tables
- DimCustomer
- DimProduct
- DimDate
- DimCountry

---

## 3. SQL Business Analysis

Performed:
- customer revenue analysis,
- churn analysis,
- retention analysis,
- cohort analysis,
- RFM segmentation,
- revenue leakage estimation.

---

## 4. Power BI Dashboarding

Developed interactive dashboards for:
- executive summary,
- customer segmentation,
- retention analysis,
- and revenue leakage tracking.

---

# Key KPIs

- Total Revenue
- Active Customers
- Churn Rate
- Retention Rate
- Repeat Purchase Rate
- Average Order Value
- Customer Lifetime Value
- Revenue Leakage

---

# Dashboard Pages

## Executive Dashboard
Tracks:
- total revenue,
- active customers,
- churn rate,
- revenue leakage,
- monthly revenue trends.

---

## Customer Segmentation Dashboard
Includes:
- RFM segment distribution,
- revenue by segment,
- top customer analysis,
- country-wise revenue contribution.

---

## Retention Analysis Dashboard
Includes:
- cohort retention heatmap,
- repeat purchase trends,
- customer retention patterns.

---

## Revenue Leakage Dashboard
Tracks:
- inactive customer revenue,
- churned customers,
- leakage percentage,
- revenue risk by segment.

---

# Dashboard Screenshots

## Executive Summary Dashboard

![Executive Summary]<img width="1440" height="810" alt="Executive Summary Dashboard" src="https://github.com/user-attachments/assets/b7188d31-3629-453b-aae2-aa27bbe4b62a" />


---

## Customer Segmentation Dashboard

![Customer Segmentation]<img width="1237" height="721" alt="Customer Segmentation" src="https://github.com/user-attachments/assets/c60ef54c-166d-447e-bfa2-400ce8ff22f6" />


---

## Retention Analysis Dashboard

![Retention Analysis]<img width="1274" height="726" alt="Retention Analysis" src="https://github.com/user-attachments/assets/474bff7e-d5fd-4c81-aa95-5487e446e7e4" />

---

## Revenue Leakage Dashboard

![Revenue Leakage]<img width="1184" height="719" alt="Revenue Leakage Analysis" src="https://github.com/user-attachments/assets/8b75b119-e4c7-4fb6-aee4-e4da1bde9b15" />

---

# Key Insights

- Champion and Loyal customers contributed the majority of total revenue.
- Customers inactive for more than 60 days showed significantly higher churn probability.
- High-value customer segments represented a small percentage of customers but generated substantial revenue contribution.
- Cohort retention declined steadily across later periods.
- Significant revenue leakage was identified from inactive and churn-prone customers.

---

# Business Recommendations

- Launch re-engagement campaigns for at-risk customers.
- Create loyalty programs for high-value customer segments.
- Monitor inactivity thresholds proactively.
- Prioritize retention strategies over excessive acquisition spending.
- Develop customer-specific marketing strategies using RFM segmentation.

---

# Author

### Manav Singh

Skills:
- SQL
- Python
- Power BI
- Data Analytics
- Business Intelligence
- ETL
- Dashboard Development


---

# Conclusion

This project demonstrates a complete end-to-end analytics workflow involving:
- business understanding,
- data cleaning,
- SQL warehouse modeling,
- customer segmentation,
- cohort analysis,
- churn analytics,
- and executive dashboarding.

The solution provides actionable insights that can help organizations improve customer retention, reduce revenue leakage, and drive long-term business growth.
