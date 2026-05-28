-- ============================================================
--  Customer Retention & Revenue Leakage Analysis
--  Script 3 & 4: Cohort + RFM Analysis
-- ============================================================

USE RetailDW;
GO

-- ============================================================
--  PART A: COHORT RETENTION MATRIX
-- ============================================================

-- ── Step 1: Find each customer's first purchase month ─────────────────────
WITH CustomerCohort AS (
    SELECT
        CustomerKey,
        MIN(OrderMonth) AS CohortMonth
    FROM dbo.FactSales
    GROUP BY CustomerKey
),

-- ── Step 2: Join back to get all active months ────────────────────────────
CohortActivity AS (
    SELECT
        f.CustomerKey,
        cc.CohortMonth,
        f.OrderMonth,
        -- Month index: 0 = cohort month, 1 = next month, etc.
        DATEDIFF(
            MONTH,
            CAST(cc.CohortMonth + '-01' AS DATE),
            CAST(f.OrderMonth  + '-01' AS DATE)
        ) AS MonthIndex
    FROM dbo.FactSales  f
    JOIN CustomerCohort cc ON cc.CustomerKey = f.CustomerKey
),

-- ── Step 3: Count distinct customers per cohort × month ──────────────────
CohortCounts AS (
    SELECT
        CohortMonth,
        MonthIndex,
        COUNT(DISTINCT CustomerKey) AS Customers
    FROM CohortActivity
    GROUP BY CohortMonth, MonthIndex
),

-- ── Step 4: Cohort sizes (month 0) ───────────────────────────────────────
CohortSizes AS (
    SELECT CohortMonth, Customers AS CohortSize
    FROM CohortCounts
    WHERE MonthIndex = 0
)

-- ── Step 5: Retention % matrix ───────────────────────────────────────────
SELECT
    cc.CohortMonth,
    cs.CohortSize,
    cc.MonthIndex,
    cc.Customers                AS ActiveCustomers,
    ROUND(cc.Customers * 100.0 / cs.CohortSize, 1) AS RetentionPct
FROM CohortCounts   cc
JOIN CohortSizes    cs ON cs.CohortMonth = cc.CohortMonth
ORDER BY cc.CohortMonth, cc.MonthIndex;
GO

-- ── Pivoted view: Cohort × Month 0–12 ────────────────────────────────────
WITH CustomerCohort AS (
    SELECT CustomerKey, MIN(OrderMonth) AS CohortMonth
    FROM dbo.FactSales GROUP BY CustomerKey
),
CohortActivity AS (
    SELECT
        f.CustomerKey, cc.CohortMonth, f.OrderMonth,
        DATEDIFF(MONTH,
            CAST(cc.CohortMonth + '-01' AS DATE),
            CAST(f.OrderMonth  + '-01' AS DATE)
        ) AS MonthIndex
    FROM dbo.FactSales f JOIN CustomerCohort cc ON cc.CustomerKey = f.CustomerKey
),
CohortCounts AS (
    SELECT CohortMonth, MonthIndex, COUNT(DISTINCT CustomerKey) AS Customers
    FROM CohortActivity GROUP BY CohortMonth, MonthIndex
),
CohortSizes AS (
    SELECT CohortMonth, Customers AS CohortSize
    FROM CohortCounts WHERE MonthIndex = 0
)
SELECT
    CohortMonth, CohortSize,
    MAX(CASE WHEN MonthIndex = 1  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month1,
    MAX(CASE WHEN MonthIndex = 2  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month2,
    MAX(CASE WHEN MonthIndex = 3  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month3,
    MAX(CASE WHEN MonthIndex = 4  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month4,
    MAX(CASE WHEN MonthIndex = 5  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month5,
    MAX(CASE WHEN MonthIndex = 6  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month6,
    MAX(CASE WHEN MonthIndex = 7  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month7,
    MAX(CASE WHEN MonthIndex = 8  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month8,
    MAX(CASE WHEN MonthIndex = 9  THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month9,
    MAX(CASE WHEN MonthIndex = 10 THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month10,
    MAX(CASE WHEN MonthIndex = 11 THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month11,
    MAX(CASE WHEN MonthIndex = 12 THEN ROUND(Customers*100.0/CohortSize,1) END) AS Month12
FROM CohortCounts cc
JOIN CohortSizes  cs ON cs.CohortMonth = cc.CohortMonth
GROUP BY CohortMonth, CohortSize
ORDER BY CohortMonth;
GO


-- ============================================================
--  PART B: RFM ANALYSIS
-- ============================================================

-- Reference date = last transaction date in dataset
DECLARE @RefDate DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);

-- ── Step 1: Raw RFM metrics per customer ─────────────────────────────────
WITH RFM_Base AS (
    SELECT
        dc.CustomerID,
        dc.Country,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate)  AS Recency,
        COUNT(DISTINCT f.Invoice)                    AS Frequency,
        SUM(f.LineRevenue)                           AS Monetary
    FROM dbo.FactSales  f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerID, dc.Country
),

-- ── Step 2: Quintile scores (1–5) ────────────────────────────────────────
RFM_Scores AS (
    SELECT
        CustomerID, Country, Recency, Frequency, Monetary,
        -- Recency: low = better → flip score
        NTILE(5) OVER (ORDER BY Recency DESC)    AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC)   AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC)    AS M_Score
    FROM RFM_Base
),

-- ── Step 3: Composite RFM code and segment ───────────────────────────────
RFM_Segmented AS (
    SELECT
        CustomerID, Country, Recency, Frequency, Monetary,
        R_Score, F_Score, M_Score,
        CAST(R_Score AS VARCHAR) + CAST(F_Score AS VARCHAR) + CAST(M_Score AS VARCHAR) AS RFM_Code,
        R_Score + F_Score + M_Score AS RFM_Total,
        CASE
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3                  THEN 'Loyal'
            WHEN R_Score >= 4 AND F_Score <= 2                  THEN 'Recent'
            WHEN R_Score >= 3 AND F_Score <= 2 AND M_Score >= 3 THEN 'Potential Loyalists'
            WHEN R_Score = 2  AND F_Score >= 2                  THEN 'At Risk'
            WHEN R_Score <= 2 AND F_Score >= 3                  THEN 'Cant Lose Them'
            WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2 THEN 'Lost'
            WHEN R_Score + F_Score + M_Score <= 5               THEN 'Hibernating'
            ELSE 'Needs Attention'
        END AS Segment
    FROM RFM_Scores
)

-- ── Final RFM output ──────────────────────────────────────────────────────
SELECT * FROM RFM_Segmented
ORDER BY Monetary DESC;
GO

-- ── RFM Segment Summary ───────────────────────────────────────────────────
DECLARE @RefDate2 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);

WITH RFM_Base AS (
    SELECT
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate2) AS Recency,
        COUNT(DISTINCT f.Invoice)                    AS Frequency,
        SUM(f.LineRevenue)                           AS Monetary,
        f.CustomerKey
    FROM dbo.FactSales f GROUP BY f.CustomerKey
),
RFM_Scores AS (
    SELECT CustomerKey, Recency, Frequency, Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC)    AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC)   AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC)    AS M_Score
    FROM RFM_Base
),
RFM_Segmented AS (
    SELECT CustomerKey, Recency, Frequency, Monetary,
        CASE
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3                  THEN 'Loyal'
            WHEN R_Score >= 4 AND F_Score <= 2                  THEN 'Recent'
            WHEN R_Score >= 3 AND F_Score <= 2 AND M_Score >= 3 THEN 'Potential Loyalists'
            WHEN R_Score = 2  AND F_Score >= 2                  THEN 'At Risk'
            WHEN R_Score <= 2 AND F_Score >= 3                  THEN 'Cant Lose Them'
            WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2 THEN 'Lost'
            WHEN R_Score + F_Score + M_Score <= 5               THEN 'Hibernating'
            ELSE 'Needs Attention'
        END AS Segment
    FROM RFM_Scores
)
SELECT
    Segment,
    COUNT(*)                AS Customers,
    ROUND(AVG(Recency),0)   AS AvgRecency,
    ROUND(AVG(Frequency),1) AS AvgFrequency,
    ROUND(SUM(Monetary),2)  AS TotalRevenue,
    ROUND(AVG(Monetary),2)  AS AvgRevenue,
    ROUND(SUM(Monetary)*100.0/SUM(SUM(Monetary)) OVER(),1) AS Revenue_Pct
FROM RFM_Segmented
GROUP BY Segment
ORDER BY TotalRevenue DESC;
GO

-- ── Update DimCustomer with RFM Segment ──────────────────────────────────
-- (Run after RFM analysis is complete)
DECLARE @RefDate3 DATE = (SELECT CAST(MAX(InvoiceDate) AS DATE) FROM dbo.FactSales);

WITH RFM_Base AS (
    SELECT
        dc.CustomerKey,
        DATEDIFF(DAY, MAX(f.InvoiceDate), @RefDate3) AS Recency,
        COUNT(DISTINCT f.Invoice)                    AS Frequency,
        SUM(f.LineRevenue)                           AS Monetary
    FROM dbo.FactSales f
    JOIN dbo.DimCustomer dc ON dc.CustomerKey = f.CustomerKey
    GROUP BY dc.CustomerKey
),
RFM_Scores AS (
    SELECT CustomerKey,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R,
        NTILE(5) OVER (ORDER BY Frequency)   AS F,
        NTILE(5) OVER (ORDER BY Monetary)    AS M
    FROM RFM_Base
),
Segments AS (
    SELECT CustomerKey,
        CASE
            WHEN R >= 4 AND F >= 4 AND M >= 4 THEN 'Champions'
            WHEN R >= 3 AND F >= 3             THEN 'Loyal'
            WHEN R >= 4 AND F <= 2             THEN 'Recent'
            WHEN R >= 3 AND F <= 2 AND M >= 3  THEN 'Potential Loyalists'
            WHEN R = 2  AND F >= 2             THEN 'At Risk'
            WHEN R <= 2 AND F >= 3             THEN 'Cant Lose Them'
            WHEN R <= 2 AND F <= 2 AND M <= 2  THEN 'Lost'
            WHEN R + F + M <= 5                THEN 'Hibernating'
            ELSE 'Needs Attention'
        END AS Segment
    FROM RFM_Scores
)
UPDATE dc
SET dc.RFM_Segment = s.Segment
FROM dbo.DimCustomer dc
JOIN Segments s ON s.CustomerKey = dc.CustomerKey;
GO

PRINT '✅ Cohort + RFM analysis complete';