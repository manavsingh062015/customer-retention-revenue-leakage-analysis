-- ============================================================
--  Customer Retention & Revenue Leakage Analysis
--  Phase 5 — Script 2: Retention Analysis
-- ============================================================

USE RetailDW;
GO

-- ── 1. Overall Retention Rate ────────────────────────────────────────────────
-- Retention = customers who made ≥2 purchases / all customers
WITH CustomerOrders AS (
    SELECT
        CustomerKey,
        COUNT(DISTINCT Invoice)         AS TotalOrders,
        COUNT(DISTINCT OrderMonth)      AS ActiveMonths,
        MIN(InvoiceDate)                AS FirstPurchase,
        MAX(InvoiceDate)                AS LastPurchase
    FROM dbo.FactSales
    GROUP BY CustomerKey
)
SELECT
    COUNT(*)                                                AS TotalCustomers,
    SUM(CASE WHEN TotalOrders > 1 THEN 1 ELSE 0 END)       AS ReturningCustomers,
    SUM(CASE WHEN TotalOrders = 1 THEN 1 ELSE 0 END)       AS OneTimeCustomers,
    ROUND(
        SUM(CASE WHEN TotalOrders > 1 THEN 1.0 ELSE 0 END) /
        COUNT(*) * 100, 2
    )                                                       AS RetentionRate_Pct,
    ROUND(
        SUM(CASE WHEN TotalOrders = 1 THEN 1.0 ELSE 0 END) /
        COUNT(*) * 100, 2
    )                                                       AS OneTimePurchaserRate_Pct
FROM CustomerOrders;
GO

-- ── 2. Monthly Retention Rate ────────────────────────────────────────────────
WITH MonthlyCustomers AS (
    SELECT DISTINCT CustomerKey, OrderMonth
    FROM dbo.FactSales
),
MonthlyWithPrev AS (
    SELECT
        mc.OrderMonth,
        mc.CustomerKey,
        LAG(mc.OrderMonth) OVER (PARTITION BY mc.CustomerKey ORDER BY mc.OrderMonth) AS PrevMonth
    FROM MonthlyCustomers mc
),
RetentionCalc AS (
    SELECT
        OrderMonth,
        COUNT(DISTINCT CustomerKey)                                             AS ActiveCustomers,
        COUNT(DISTINCT CASE WHEN PrevMonth IS NOT NULL THEN CustomerKey END)   AS RetainedCustomers
    FROM MonthlyWithPrev
    GROUP BY OrderMonth
)
SELECT
    OrderMonth,
    ActiveCustomers,
    RetainedCustomers,
    ActiveCustomers - RetainedCustomers     AS NewCustomers,
    ROUND(
        CASE WHEN LAG(ActiveCustomers) OVER (ORDER BY OrderMonth) > 0
             THEN RetainedCustomers * 100.0 / LAG(ActiveCustomers) OVER (ORDER BY OrderMonth)
             ELSE NULL END, 2
    )                                       AS MonthlyRetentionRate_Pct
FROM RetentionCalc
ORDER BY OrderMonth;
GO

-- ── 3. Churn Rate per Month ──────────────────────────────────────────────────
WITH MonthlyActive AS (
    SELECT OrderMonth, COUNT(DISTINCT CustomerKey) AS ActiveCount
    FROM dbo.FactSales
    GROUP BY OrderMonth
)
SELECT
    OrderMonth,
    ActiveCount,
    LAG(ActiveCount) OVER (ORDER BY OrderMonth)     AS PrevMonthActive,
    ROUND(
        CASE WHEN LAG(ActiveCount) OVER (ORDER BY OrderMonth) > 0
             THEN (1 - ActiveCount * 1.0 / LAG(ActiveCount) OVER (ORDER BY OrderMonth)) * 100
             ELSE NULL END, 2
    )                                               AS MonthlyChurnRate_Pct
FROM MonthlyActive
ORDER BY OrderMonth;
GO

-- ── 4. Repeat Purchase Rate ──────────────────────────────────────────────────
WITH CustomerPurchases AS (
    SELECT CustomerKey, COUNT(DISTINCT Invoice) AS NumOrders
    FROM dbo.FactSales
    GROUP BY CustomerKey
)
SELECT
    COUNT(*)                                AS TotalCustomers,
    SUM(CASE WHEN NumOrders >= 2 THEN 1 ELSE 0 END)    AS RepeatCustomers,
    SUM(CASE WHEN NumOrders >= 3 THEN 1 ELSE 0 END)    AS LoyalCustomers_3plus,
    SUM(CASE WHEN NumOrders >= 5 THEN 1 ELSE 0 END)    AS HighFrequency_5plus,
    ROUND(SUM(CASE WHEN NumOrders >= 2 THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2)
                                            AS RepeatPurchaseRate_Pct,
    AVG(CAST(NumOrders AS FLOAT))           AS AvgOrdersPerCustomer
FROM CustomerPurchases;
GO

-- ── 5. Customer Lifetime: Days between First and Last Purchase ───────────────
WITH Tenure AS (
    SELECT
        dc.CustomerID,
        dc.Country,
        MIN(f.InvoiceDate)  AS FirstPurchase,
        MAX(f.InvoiceDate)  AS LastPurchase,
        DATEDIFF(DAY, MIN(f.InvoiceDate), MAX(f.InvoiceDate)) AS TenureDays,
        COUNT(DISTINCT f.Invoice) AS TotalOrders,
        SUM(f.LineRevenue)        AS TotalRevenue
    FROM dbo.FactSales f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID, dc.Country
)
SELECT
    AVG(TenureDays)     AS AvgTenureDays,
    MAX(TenureDays)     AS MaxTenureDays,
    AVG(TotalOrders)    AS AvgOrders,
    AVG(TotalRevenue)   AS AvgLifetimeRevenue,
    -- Bucket customers
    SUM(CASE WHEN TenureDays = 0             THEN 1 ELSE 0 END) AS OneDay_Customers,
    SUM(CASE WHEN TenureDays BETWEEN 1  AND 30  THEN 1 ELSE 0 END) AS Under30d,
    SUM(CASE WHEN TenureDays BETWEEN 31 AND 90  THEN 1 ELSE 0 END) AS Under90d,
    SUM(CASE WHEN TenureDays BETWEEN 91 AND 180 THEN 1 ELSE 0 END) AS Under180d,
    SUM(CASE WHEN TenureDays > 180              THEN 1 ELSE 0 END) AS Over180d
FROM Tenure;
GO