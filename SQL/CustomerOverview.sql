
-- ============================================================
--  Customer Retention & Revenue Leakage Analysis
--  Phase 5 — Script 1: Customer Overview
-- ============================================================

USE RetailDW;
GO

-- ── 1. Top 10 Customers by Revenue ──────────────────────────────────────────
SELECT TOP 10
    dc.CustomerID,
    dc.Country,
    SUM(f.LineRevenue)          AS TotalRevenue,
    COUNT(DISTINCT f.Invoice)   AS TotalOrders,
    AVG(f.LineRevenue)          AS AvgLineValue,
    MIN(f.InvoiceDate)          AS FirstPurchase,
    MAX(f.InvoiceDate)          AS LastPurchase,
    DATEDIFF(DAY, MAX(f.InvoiceDate), GETDATE()) AS DaysSinceLastOrder
FROM dbo.FactSales  f
JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
GROUP BY dc.CustomerID, dc.Country
ORDER BY TotalRevenue DESC;
GO

-- ── 2. Average Order Value (AOV) ────────────────────────────────────────────
SELECT
    COUNT(DISTINCT f.Invoice)                               AS TotalOrders,
    SUM(f.LineRevenue)                                      AS TotalRevenue,
    SUM(f.LineRevenue) / COUNT(DISTINCT f.Invoice)          AS AvgOrderValue,
    MIN(f.LineRevenue)                                      AS MinOrderValue,
    MAX(f.LineRevenue)                                      AS MaxOrderValue,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.LineRevenue)
        OVER ()                                             AS MedianLineValue
FROM dbo.FactSales f;
GO

-- Order-level AOV (sum per invoice first, then average)
SELECT
    AVG(OrderTotal) AS AvgOrderValue_Correct
FROM (
    SELECT Invoice, SUM(LineRevenue) AS OrderTotal
    FROM dbo.FactSales
    GROUP BY Invoice
) AS InvoiceTotals;
GO

-- ── 3. Revenue by Country ────────────────────────────────────────────────────
SELECT
    dco.CountryName,
    COUNT(DISTINCT f.CustomerKey)   AS UniqueCustomers,
    COUNT(DISTINCT f.Invoice)       AS TotalOrders,
    SUM(f.LineRevenue)              AS TotalRevenue,
    ROUND(
        SUM(f.LineRevenue) * 100.0 /
        SUM(SUM(f.LineRevenue)) OVER(), 2
    )                               AS Revenue_Pct,
    SUM(f.LineRevenue) / COUNT(DISTINCT f.Invoice)  AS AOV
FROM dbo.FactSales  f
JOIN dbo.DimCountry dco ON dco.CountryKey = f.CountryKey
GROUP BY dco.CountryName
ORDER BY TotalRevenue DESC;
GO

-- ── 4. Monthly Active Customers ──────────────────────────────────────────────
SELECT
    f.OrderMonth,
    COUNT(DISTINCT f.CustomerKey)   AS ActiveCustomers,
    COUNT(DISTINCT f.Invoice)       AS Orders,
    SUM(f.LineRevenue)              AS MonthlyRevenue,
    SUM(f.LineRevenue) / COUNT(DISTINCT f.Invoice)  AS AOV,
    SUM(f.Quantity)                 AS ItemsSold
FROM dbo.FactSales f
GROUP BY f.OrderMonth
ORDER BY f.OrderMonth;
GO

-- ── 5. New vs. Returning Customers per Month ─────────────────────────────────
WITH FirstPurchases AS (
    SELECT CustomerKey, MIN(OrderMonth) AS FirstMonth
    FROM dbo.FactSales
    GROUP BY CustomerKey
)
SELECT
    f.OrderMonth,
    COUNT(DISTINCT CASE WHEN fp.FirstMonth = f.OrderMonth THEN f.CustomerKey END) AS NewCustomers,
    COUNT(DISTINCT CASE WHEN fp.FirstMonth <> f.OrderMonth THEN f.CustomerKey END) AS ReturningCustomers,
    COUNT(DISTINCT f.CustomerKey) AS TotalActive
FROM dbo.FactSales f
JOIN FirstPurchases fp ON fp.CustomerKey = f.CustomerKey
GROUP BY f.OrderMonth
ORDER BY f.OrderMonth;
GO

-- ── 6. Revenue Quartile Distribution ────────────────────────────────────────
WITH CustomerRevenue AS (
    SELECT
        dc.CustomerID,
        SUM(f.LineRevenue) AS TotalRevenue,
        NTILE(4) OVER (ORDER BY SUM(f.LineRevenue)) AS Quartile
    FROM dbo.FactSales  f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID
)
SELECT
    CASE Quartile
        WHEN 1 THEN 'Q1 — Bottom 25%'
        WHEN 2 THEN 'Q2 — 25–50%'
        WHEN 3 THEN 'Q3 — 50–75%'
        WHEN 4 THEN 'Q4 — Top 25%'
    END AS RevenueQuartile,
    COUNT(*)         AS Customers,
    SUM(TotalRevenue) AS TotalRevenue,
    ROUND(SUM(TotalRevenue) * 100.0 / SUM(SUM(TotalRevenue)) OVER (), 1) AS Revenue_Pct
FROM CustomerRevenue
GROUP BY Quartile
ORDER BY Quartile;
GO





