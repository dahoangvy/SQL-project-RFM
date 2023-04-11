SELECT * 
FROM dbo.sales_sample_data

/* Câu hỏi có thể đặt ra từ bộ dữ liệu 
- Lợi nhuận/ Doanh thu có tăng trưởng theo thời gian hay không
- Quốc gia nào đang đem lại lợi nhuận, doanh thu cao nhất
- Xác định khách hàng theo từng tập sử dụng RFM */  

-- Tính chỉ tiêu theo từng tháng 

SELECT Year, 
Month, 
MonthName,
SUM(SalesAmount) as TotalSales,
SUM(Profit) as TotalProfit, 
SUM(Cost) as TotalCost, 
COUNT(SalesOrderNumber) as TotalOrders, 
SUM(SalesAmount) / COUNT(SalesOrderNumber) as AOV 
FROM dbo.sales_sample_data
GROUP BY Year, Month, MonthName
ORDER BY Year DESC, Month DESC

-- Biểu đồ Trending Sales by Month: Không có sự tăng trưởng về Profit, Sales có tăng trưởng cao vào 2 tháng đầu năm 2020
-- Total Revenue giảm nhẹ so với tháng trước
-- Total Number of Orders tăng gấp đôi so với tháng trước 
-- Tìm hiểu nguyên do -> Dự kiến là do giá trị trung bình (AOV) mỗi đơn hàng giảm 
-- Kết luận: Tổng doanh thu giảm do số lượng đơn tăng nhưng AOV còn nhỏ -> Cần có action đẩy AOV 

-- Câu hỏi 2: 
-- Quốc gia đem lại lợi nhuận, doanh thu cao nhất 

SELECT Country,
SUM(SalesAmount) as TotalSales, 
SUM(Cost) as TotalCost, 
SUM(Profit) as TotalProfit
FROM dbo.sales_sample_data
GROUP BY Country
ORDER BY TotalProfit ASC

-- RFM analysis
WITH Sales_by_Customer AS (

SELECT CustomerKey,
MAX(OrderDate) as LastOrderDate, 
COUNT(SalesOrderNumber) as Frequency,
SUM(SalesAmount) as Monetary,
(SELECT MAX(OrderDate) FROM dbo.sales_sample_data) as MaxDate,
DATEDIFF(DAY, MAX(OrderDate), (SELECT MAX(OrderDate) FROM dbo.sales_sample_data)) as Recency
FROM dbo.sales_sample_data
GROUP BY CustomerKey)

, Rfm_calc AS (
SELECT CustomerKey,
NTILE(4) OVER (ORDER BY Recency DESC ) as rfm_recency, 
NTILE(4) OVER (ORDER BY Frequency) as rfm_frequency, 
NTILE(4) OVER (ORDER BY Monetary) as rfm_monetary
FROM Sales_by_Customer) 

, RFM_score AS (
SELECT CustomerKey,
CONCAT(rfm_recency, rfm_frequency, rfm_monetary) as RFM_score
FROM Rfm_calc)

-- Lost customer: Mua từ rất lâu rồi, Recency thấp -> 1xx
-- Big spenders: Mua với giá trị đơn hàng lớn nhưng tấn suất mua ít -> X14, X24 
-- Promising: Mua gần đây, tần suất nhiều nhưng giá trị đơn hàng còn thấp -> [3,4][3,4][1,2]
-- New customer: Mua gần đây, tần suất thấp -> [3,4][1,2]_ 
-- Potential churn (Có khả năng rời bỏ): Mua từ khá lâu rồi, Recency khá thấp-> 2XX
-- Loyal: Mua gần đây, tần suất cao, giá trị đơn cao -> [3/4][3/4][3/4]

, Rfm_segmentation AS (
SELECT CustomerKey,
RFM_score,
CASE 
WHEN rfm_score LIKE '1__' THEN 'Lost customer' 
WHEN rfm_score LIKE '_[1,2]4' THEN 'Big spenders' 
WHEN rfm_score LIKE '[3,4][3,4][1,2]' THEN 'Promising' 
WHEN rfm_score LIKE '[3,4][1,2]_' THEN 'New customer'
WHEN rfm_score LIKE '2__' THEN 'Potential churn' 
WHEN rfm_score LIKE '[3,4][3,4][3,4]' THEN 'Loyal'
END AS CustomerSegmentation
FROM rfm_score) 

SELECT 
CustomerSegmentation, COUNT(CustomerKey) as TotalCustomers
FROM Rfm_segmentation
GROUP BY CustomerSegmentation