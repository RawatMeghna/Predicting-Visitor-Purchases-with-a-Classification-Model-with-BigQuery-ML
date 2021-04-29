# Predicting Visitor Purchases with a Classification Model with BigQuery ML
I have used ecommerce data from the real Google Ecommerce storefront: https://shop.googlemerchandisestore.com/ 

Firstly, I loaded their visitor and order data into BigQuery and then built a machine learning model to predict whether a visitor will return for more purchases later.

Here, I have trained my data on two models : Logistic Regression and XGBoost Classifier

### Overview

__BigQuery ML__ (BigQuery machine learning) is a feature in BigQuery where data analysts can create, train, evaluate, and predict with machine learning models with minimal coding.

The Google Analytics Sample Ecommerce dataset that has millions of ____Google Analytics___ records for the Google Merchandise Store loaded into BigQuery. In this lab, you will use this data to run some typical queries that businesses would want to know about their customers' purchasing habits.

### Objectives
 1. Use BigQuery to find public datasets
 2. Query and explore the ecommerce dataset
 3. Create a training and evaluation dataset to be used for batch prediction
 4. Create a classification (logistic regression) model in BigQuery ML
 5. Evaluate the performance of your machine learning model
 6. Predict and rank the probability that a visitor will make a purchase
