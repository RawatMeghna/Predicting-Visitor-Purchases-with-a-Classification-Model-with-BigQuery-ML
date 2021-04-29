# EXPLORE ECOMMERCE DATA

#### Query 1, to find out of the total visitors who visited the website, what % made a purchase

```sql
#standardSQL
WITH visitors AS(
SELECT
COUNT(DISTINCT fullVisitorId) AS total_visitors
FROM `data-to-insights.ecommerce.web_analytics`
),

purchasers AS(
SELECT
COUNT(DISTINCT fullVisitorId) AS total_purchasers
FROM `data-to-insights.ecommerce.web_analytics`
WHERE totals.transactions IS NOT NULL
)

SELECT
  total_visitors,
  total_purchasers,
  total_purchasers / total_visitors AS conversion_rate
FROM visitors, purchasers
```

##### Output:
| total_visitors |                        total_purchasers                   |     conversion_rate    | 
| :--------------| :------------------------------------------------------:| :----------------------: |
|     741721     |                             20015                         |	0.026984540008979     |	

##### The result: 2.69%


#### Query 2, to find out who are the top 5 selling products

```sql
SELECT
  p.v2ProductName,
  p.v2ProductCategory,
  SUM(p.productQuantity) AS units_sold,
  ROUND(SUM(p.localProductRevenue/1000000),2) AS revenue
FROM `data-to-insights.ecommerce.web_analytics`,
UNNEST(hits) AS h,
UNNEST(h.product) AS p
GROUP BY 1, 2
ORDER BY revenue DESC
LIMIT 5;
```
##### Output :
| Row  |                        v2ProductName                    |     v2ProductCategory    | units_sold | revenue |
| :----| :------------------------------------------------------:| :----------------------: | :--------: | :-----: |
|  1	 | Nest® Learning Thermostat 3rd Gen-USA - Stainless Steel |	Nest-USA                |	17651	     |870976.95|
|  2	 | Nest® Cam Outdoor Security Camera - USA                 |	Nest-USA	              | 16930	     |684034.55|
|  3	 | Nest® Cam Indoor Security Camera - USA	                 |  Nest-USA	              | 14155	     |548104.47|
|  4	 | Nest® Protect Smoke + CO White Wired Alarm-USA          |	Nest-USA	              | 6394	     |178937.6 |
|  5	 | Nest® Protect Smoke + CO White Battery Alarm-USA	       |  Nest-USA	              | 6340       |178572.4 |

#### Query 3, to find out how many visitors bought on subsequent visits to the website

##### visitors who bought on a return visit (could have bought on first as well)

```SQL
WITH all_visitor_stats AS (
SELECT
  fullvisitorid, # 741,721 unique visitors
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

SELECT
  COUNT(DISTINCT fullvisitorid) AS total_visitors,
  will_buy_on_return_visit
FROM all_visitor_stats
GROUP BY will_buy_on_return_visit

```

##### Output:
|  Row | total_visitors |  will_buy_on_return_visit | 
| :----| :-------------:| :-----------------------: |
|  1   |     729848     |	            0             |	
|  2   |     11873      |	            1             |	

#### Analyzing the results, we can see that (11873 / 729848) = __1.6%__ of total visitors will return and purchase from the website. 
#### This includes the subset of visitors who bought on their very first session and then came back and bought again.

####  Now, the reasons a typical ecommerce customer will browse but not buy until a later visit are:
      1. The customer wants to comparison shop on other sites before making a purchase decision
      2. The customer is waiting for products to go on sale or other promotion
      3. The customer is doing additional research

#### This behavior is very common for luxury goods where significant up-front research and comparison is required by the customer before deciding (think car purchases) but also true to a lesser extent for the merchandise on this site (t-shirts, accessories, etc).

#### In the world of online marketing, identifying and marketing to these future customers based on the characteristics of their first visit will increase conversion rates and reduce the outflow to competitor sites.
