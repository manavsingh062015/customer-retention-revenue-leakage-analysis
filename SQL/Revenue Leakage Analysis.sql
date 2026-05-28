-- ============================================================
--  Customer Retention & Revenue Leakage Analysis
--  Phase 5 — Script 5: Revenue Leakage Analysis
-- ============================================================

USE RetailDW;
GO

DECLARE @RefDate DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @ChurnDays INT = 90;    -- adjust to your churn threshold

-- ── 1. Revenue from Now-Inactive Customers ────────────────────────────────
WITH CustomerActivity AS (
    SELECT
        dc.CustomerID,
        dc.Country,
        dc.RFM_Segment,
        SUM(f.LineRevenue)                               AS TotalRevenue,
        COUNT(DISTINCT f.Invoice)                        AS TotalOrders,
        MAX(f.InvoiceDate)                               AS LastPurchase,
        MIN(f.InvoiceDate)                               AS FirstPurchase,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate)      AS DaysSinceLast
    FROM dbo.FactSales  f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID, dc.Country, dc.RFM_Segment
)
SELECT
    CASE
        WHEN DaysSinceLast <= 30             THEN 'Active (≤30d)'
        WHEN DaysSinceLast <= @ChurnDays     THEN 'At Risk'
        WHEN DaysSinceLast <= 365            THEN 'Inactive'
        ELSE                                      'Churned (>1yr)'
    END AS CustomerStatus,
    COUNT(*)                AS Customers,
    ROUND(SUM(TotalRevenue),2) AS TotalRevenue,
    ROUND(AVG(TotalRevenue),2) AS AvgRevenue,
    ROUND(AVG(DaysSinceLast),0) AS AvgDaysSinceLastPurchase,
    ROUND(
        SUM(TotalRevenue) * 100.0 /
        SUM(SUM(TotalRevenue)) OVER (), 1
    )                       AS Revenue_Pct
FROM CustomerActivity
GROUP BY CASE
    WHEN DaysSinceLast <= 30             THEN 'Active (≤30d)'
    WHEN DaysSinceLast <= @ChurnDays     THEN 'At Risk'
    WHEN DaysSinceLast <= 365            THEN 'Inactive'
    ELSE                                      'Churned (>1yr)'
END
ORDER BY TotalRevenue DESC;
GO


-- ── 2. Lost High-Value Customers (Top 25% revenue, now inactive) ──────────
DECLARE @RefDate2 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @ChurnDays2 INT = 90;

WITH CustomerRevenue AS (
    SELECT
        dc.CustomerID,
        dc.Country,
        dc.RFM_Segment,
        SUM(f.LineRevenue)                               AS TotalRevenue,
        COUNT(DISTINCT f.Invoice)                        AS TotalOrders,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate2)     AS DaysSinceLast
    FROM dbo.FactSales  f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID, dc.Country, dc.RFM_Segment
),
RevPercentile AS (
    SELECT *,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TotalRevenue)
            OVER () AS P75_Revenue
    FROM CustomerRevenue
)
SELECT TOP 30
    CustomerID,
    Country,
    RFM_Segment,
    TotalRevenue,
    TotalOrders,
    DaysSinceLast,
    CASE
        WHEN DaysSinceLast > 365            THEN 'Churned (>1yr)'
        WHEN DaysSinceLast > @ChurnDays2    THEN 'Inactive'
        ELSE                                     'At Risk'
    END AS Status
FROM RevPercentile
WHERE DaysSinceLast > @ChurnDays2
  AND TotalRevenue >= P75_Revenue
ORDER BY TotalRevenue DESC;
GO


-- ── 3. Estimated Annual Revenue Loss from Churned Customers ──────────────
DECLARE @RefDate3  DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @StartDate DATE = (SELECT CAST(MIN(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @SpanMonths FLOAT = DATEDIFF(MONTH, @StartDate, @RefDate3);

WITH CustomerMetrics AS (
    SELECT
        dc.CustomerKey,
        SUM(f.LineRevenue)                           AS TotalRevenue,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate3) AS DaysSinceLast
    FROM dbo.FactSales f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerKey
)
SELECT
    -- Avg monthly revenue per customer across the whole period
    SUM(TotalRevenue) / (COUNT(*) * @SpanMonths)             AS AvgMonthlyRevenuePerCustomer,
    COUNT(CASE WHEN DaysSinceLast > 365 THEN 1 END)          AS ChurnedCustomers,
    -- Estimated lost revenue = churned customers × avg monthly rev × 12
    ROUND(
        (SUM(TotalRevenue) / (COUNT(*) * @SpanMonths)) *
        COUNT(CASE WHEN DaysSinceLast > 365 THEN 1 END) * 12,
        2
    )                                                        AS EstimatedAnnualRevenueLoss
FROM CustomerMetrics;
GO


-- ── 4. Monthly Revenue Trend from Inactive vs Active Customers ────────────
DECLARE @RefDate4 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @ChurnDays4 INT = 90;

WITH CustomerStatus AS (
    SELECT
        CustomerKey,
        CASE
            WHEN DATEDIFF(DAY, MAX(InvoiceDate), @RefDate4) <= @ChurnDays4
                THEN 'Active'
            ELSE 'Inactive/Churned'
        END AS CurrentStatus
    FROM dbo.FactSales
    GROUP BY CustomerKey
)
SELECT
    f.OrderMonth,
    cs.CurrentStatus,
    COUNT(DISTINCT f.CustomerKey)   AS Customers,
    SUM(f.LineRevenue)              AS Revenue
FROM dbo.FactSales f
JOIN CustomerStatus cs ON cs.CustomerKey = f.CustomerKey
GROUP BY f.OrderMonth, cs.CurrentStatus
ORDER BY f.OrderMonth, cs.CurrentStatus;
GO


-- ── 5. Product-level Revenue at Risk ─────────────────────────────────────
-- Which products are most purchased by at-risk / inactive customers?
DECLARE @RefDate5 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @ChurnDays5 INT = 90;

WITH AtRiskCustomers AS (
    SELECT CustomerKey
    FROM dbo.FactSales
    GROUP BY CustomerKey
    HAVING DATEDIFF(DAY, MAX(InvoiceDate), @RefDate5) BETWEEN @ChurnDays5 AND 365
)
SELECT TOP 20
    dp.Description,
    dp.StockCode,
    COUNT(DISTINCT f.CustomerKey)   AS AtRiskCustomers,
    SUM(f.LineRevenue)              AS TotalRevenue,
    SUM(f.Quantity)                 AS TotalUnits
FROM dbo.FactSales f
JOIN dbo.DimProduct dp ON dp.ProductKey = f.ProductKey
WHERE f.CustomerKey IN (SELECT CustomerKey FROM AtRiskCustomers)
GROUP BY dp.Description, dp.StockCode
ORDER BY TotalRevenue DESC;
GO


-- ── 6. Re-engagement Opportunity Summary ─────────────────────────────────
DECLARE @RefDate6 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);
DECLARE @ChurnDays6 INT = 90;

WITH CustomerSummary AS (
    SELECT
        dc.CustomerID,
        dc.Country,
        dc.RFM_Segment,
        SUM(f.LineRevenue)                               AS HistoricalRevenue,
        COUNT(DISTINCT f.Invoice)                        AS Orders,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate6)     AS DaysSinceLast
    FROM dbo.FactSales  f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID, dc.Country, dc.RFM_Segment
)
SELECT
    'At Risk'                          AS TargetGroup,
    COUNT(*)                           AS Customers,
    ROUND(SUM(HistoricalRevenue), 2)   AS HistoricalRevenue,
    -- Estimated recoverable: assume 30% win-back rate
    ROUND(SUM(HistoricalRevenue) * 0.30, 2) AS EstimatedRecoverable_30pct,
    ROUND(SUM(HistoricalRevenue) * 0.15, 2) AS EstimatedRecoverable_15pct
FROM CustomerSummary
WHERE DaysSinceLast BETWEEN @ChurnDays6 AND 365

UNION ALL

SELECT
    'Churned (>1yr)',
    COUNT(*),
    ROUND(SUM(HistoricalRevenue), 2),
    ROUND(SUM(HistoricalRevenue) * 0.10, 2),
    ROUND(SUM(HistoricalRevenue) * 0.05, 2)
FROM CustomerSummary
WHERE DaysSinceLast > 365;
GO

PRINT '✅ Revenue leakage analysis complete';