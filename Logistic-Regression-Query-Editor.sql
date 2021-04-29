# TASK 1 :- EXPLORE ECOMMERCE DATA

# Query 1, to find out of the total visitors who visited the website, what % made a purchase

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

#The result: 2.69%


# Query2, to find out who are the top 5 selling products

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


# Query 3, to find out how many visitors bought on subsequent visits to the website
# Results - Check out Query3.csv

# Analyzing the results, we can see that (11873 / 729848) = 1.6% of total visitors will return and purchase from the website. 
# This includes the subset of visitors who bought on their very first session and then came back and bought again.

# Now, the reasons a typical ecommerce customer will browse but not buy until a later visit are:
# a) The customer wants to comparison shop on other sites before making a purchase decision
# b) The customer is waiting for products to go on sale or other promotion
# c) The customer is doing additional research

# This behavior is very common for luxury goods where significant up-front research and comparison is required by the customer before deciding (think car purchases) but also true to a lesser extent for the merchandise on this site (t-shirts, accessories, etc).

# In the world of online marketing, identifying and marketing to these future customers based on the characteristics of their first visit will increase conversion rates and reduce the outflow to competitor sites.



# TASK 2 :- SELECT FEATURES AND CREATE our TRAINING DATASET

# Now we will create a Machine Learning model in BigQuery to predict whether or not a new user is likely to purchase in the future. Identifying these high-value users can help our marketing team target them with special promotions and ad campaigns to ensure a conversion while they comparison shop between visits to our ecommerce site.

# Google Analytics captures a wide variety of dimensions and measures about a user's visit on this ecommerce website. Browse the complete list of fields here and then preview the demo dataset to find useful features that will help a machine learning model understand the relationship between data about a visitor's first time on our website and whether they will return and make a purchase.

# Our team decides to test whether these two fields are good inputs for our classification model:
# 1. totals.bounces (whether the visitor left the website immediately)
# 2. totals.timeOnSite (how long the visitor was on our website)

# The features are bounces and time_on_site. The label is will_buy_on_return_visit. 
# It's often too early to tell before training and evaluating the model, but at first glance out of the top 10 time_on_site, only 1 customer returned to buy, which isn't very promising. Let's see how well the model does.



# TASK 3 :- CREATE A BIGQUERY DATASET TO STORE MODELS
# GO TO BIGQUERY >> CREATE DATASET >> DONE



# TASK 4 :- SELECT A BIGQUERY ML MODEL TYPE AND SPECIFY OPTIONS
# Here, we will choose Classification model (like logistic_reg etc.) as we have to predict whether or not a customer will return to the website.

# Enter the following query to create a model and specify model options:

# MODEL - 1 : ecommerce.classification_model

CREATE OR REPLACE MODEL `ecommerce.classification_model`
OPTIONS
(
model_type='logistic_reg',
labels = ['will_buy_on_return_visit']
)
AS

#standardSQL
SELECT
  * EXCEPT(fullVisitorId)
FROM

  # features
  (SELECT
    fullVisitorId,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site
  FROM
    `data-to-insights.ecommerce.web_analytics`
  WHERE
    totals.newVisits = 1
    AND date BETWEEN '20160801' AND '20170430') # train on first 9 months
  JOIN
  (SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM
      `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid)
  USING (fullVisitorId)
;



Task 5 :- EVALUATE CLASSIFICATION MODEL PERFORMANCE

# Select the performance criteria
# For classification problems in ML, we want to minimize the False Positive Rate (predict that the user will return and purchase and they don't) and maximize the True Positive Rate (predict that the user will return and purchase and they do).

# This relationship is visualized with a ROC (Receiver Operating Characteristic) where we try to maximize the area under the curve or AUC:

# Image : Roc_curve.Png

# In BigQuery ML, roc_auc is simply a queryable field when evaluating our trained ML model.

# Now that training is complete, we can evaluate how well the model performs by running this query using ML.EVALUATE:

SELECT
  roc_auc,
  CASE
    WHEN roc_auc > .9 THEN 'good'
    WHEN roc_auc > .8 THEN 'fair'
    WHEN roc_auc > .7 THEN 'not great'
  ELSE 'poor' END AS model_quality
FROM
  ML.EVALUATE(MODEL ecommerce.classification_model,  (

SELECT
  * EXCEPT(fullVisitorId)
FROM

  # features
  (SELECT
    fullVisitorId,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site
  FROM
    `data-to-insights.ecommerce.web_analytics`
  WHERE
    totals.newVisits = 1
    AND date BETWEEN '20170501' AND '20170630') # eval on 2 months
  JOIN
  (SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM
      `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid)
  USING (fullVisitorId)

));

# We should see the following result:
#      Row  	  roc_auc	    model_quality
#       1	      0.724588	    not great
#v After evaluating our model we get a roc_auc of 0.72, which shows that the model has not great predictive power. Since the goal is to get the area under the curve as close to 1.0 as possible, there is room for improvement



# Task 6 :- IMPROVE MODEL PERFORMANCE WITH FEATURE ENGINEERING

# As was hinted at earlier, there are many more features in the dataset that may help the model better understand the relationship between a visitor's first session and the likelihood that they will purchase on a subsequent visit.

# Add some new features and create a second machine learning model called classification_model_2:
# >> How far the visitor got in the checkout process on their first visit
# >> Where the visitor came from (traffic source: organic search, referring site etc.)
# >> Device category (mobile, tablet, desktop)
# >> Geographic information (country)

# Create this second model by running the below query:

# MODEL - 2 : ecommerce.classification_model_2

CREATE OR REPLACE MODEL `ecommerce.classification_model_2`
OPTIONS
  (model_type='logistic_reg', labels = ['will_buy_on_return_visit']) AS

WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

# add in new features
SELECT * EXCEPT(unique_session_id) FROM (

  SELECT
      CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,

      # labels
      will_buy_on_return_visit,

      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,

      # behavior on the site
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      totals.pageviews,

      # where the visitor came from
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,

      # mobile or desktop
      device.deviceCategory,

      # geographic
      IFNULL(geoNetwork.country, "") AS country

  FROM `data-to-insights.ecommerce.web_analytics`,
     UNNEST(hits) AS h

    JOIN all_visitor_stats USING(fullvisitorid)

  WHERE 1=1
    # only predict for new visits
    AND totals.newVisits = 1
    AND date BETWEEN '20160801' AND '20170430' # train 9 months

  GROUP BY
  unique_session_id,
  will_buy_on_return_visit,
  bounces,
  time_on_site,
  totals.pageviews,
  trafficSource.source,
  trafficSource.medium,
  channelGrouping,
  device.deviceCategory,
  country
);

# Note: we are still training on the same first 9 months of data, even with this new model. It's important to have the same training dataset so we can be certain a better model output is attributable to better input features and not new or different training data.
A key new feature that was added to the training dataset query is the maximum checkout progress each visitor reached in their session, which is recorded in the field hits.eCommerceAction.action_type. If we search for that field in the field definitions we will see the field mapping of 6 = Completed Purchase.

# As an aside, the web analytics dataset has nested and repeated fields like ARRAYS which need to be broken apart into separate rows in our dataset. This is accomplished by using the UNNEST() function, which we can see in the above query.

# Evaluate this new model to see if there is better predictive power by running the below query:

#standardSQL
SELECT
  roc_auc,
  CASE
    WHEN roc_auc > .9 THEN 'good'
    WHEN roc_auc > .8 THEN 'fair'
    WHEN roc_auc > .7 THEN 'not great'
  ELSE 'poor' END AS model_quality
FROM
  ML.EVALUATE(MODEL ecommerce.classification_model_2,  (

WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

# add in new features
SELECT * EXCEPT(unique_session_id) FROM (

  SELECT
      CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,

      # labels
      will_buy_on_return_visit,

      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,

      # behavior on the site
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      totals.pageviews,

      # where the visitor came from
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,

      # mobile or desktop
      device.deviceCategory,

      # geographic
      IFNULL(geoNetwork.country, "") AS country

  FROM `data-to-insights.ecommerce.web_analytics`,
     UNNEST(hits) AS h

    JOIN all_visitor_stats USING(fullvisitorid)

  WHERE 1=1
    # only predict for new visits
    AND totals.newVisits = 1
    AND date BETWEEN '20170501' AND '20170630' # eval 2 months

  GROUP BY
  unique_session_id,
  will_buy_on_return_visit,
  bounces,
  time_on_site,
  totals.pageviews,
  trafficSource.source,
  trafficSource.medium,
  channelGrouping,
  device.deviceCategory,
  country
)
));

# (Output)
#   Row	       roc_auc	    model_quality
#    1 	      0.910382	        good

# With this new model we now get a roc_auc of 0.91 which is significantly better than the first model.

# Now that we have a trained model, time to make some predictions.



# Task 7 :- PREDICT WHICH NEW VISITORS WILL COME BACK AND PURCHASE

# Next we will write a query to predict which new visitors will come back and make a purchase.

# Run the prediction query below which uses the improved classification model to predict the probability that a first-time visitor to the Google Merchandise Store will make a purchase in a later visit:

SELECT
*
FROM
  ml.PREDICT(MODEL `ecommerce.classification_model_2`,
   (

WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

  SELECT
      CONCAT(fullvisitorid, '-',CAST(visitId AS STRING)) AS unique_session_id,

      # labels
      will_buy_on_return_visit,

      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,

      # behavior on the site
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      totals.pageviews,

      # where the visitor came from
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,

      # mobile or desktop
      device.deviceCategory,

      # geographic
      IFNULL(geoNetwork.country, "") AS country

  FROM `data-to-insights.ecommerce.web_analytics`,
     UNNEST(hits) AS h

    JOIN all_visitor_stats USING(fullvisitorid)

  WHERE
    # only predict for new visits
    totals.newVisits = 1
    AND date BETWEEN '20170701' AND '20170801' # test 1 month

  GROUP BY
  unique_session_id,
  will_buy_on_return_visit,
  bounces,
  time_on_site,
  totals.pageviews,
  trafficSource.source,
  trafficSource.medium,
  channelGrouping,
  device.deviceCategory,
  country
)

)

ORDER BY
  predicted_will_buy_on_return_visit DESC;
  
# The predictions are made in the last 1 month (out of 12 months) of the dataset.

# Our model will now output the predictions it has for those July 2017 ecommerce sessions. We can see three newly added fields:

# predicted_will_buy_on_return_visit: whether the model thinks the visitor will buy later (1 = yes)
# predicted_will_buy_on_return_visit_probs.label: the binary classifier for yes / no
# predicted_will_buy_on_return_visit.prob: the confidence the model has in it's prediction (1 = 100%)

# Results
# Of the top 6% of first-time visitors (sorted in decreasing order of predicted probability), more than 6% make a purchase in a later visit.

# These users represent nearly 50% of all first-time visitors who make a purchase in a later visit.

# Overall, only 0.7% of first-time visitors make a purchase in a later visit.

# Targeting the top 6% of first-time increases marketing ROI by 9x vs targeting them all!
