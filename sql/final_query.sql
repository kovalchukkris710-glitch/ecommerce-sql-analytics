-- Combine tables and retrieve the required data for further analysis 
WITH account_session_country AS (
    SELECT
        s.date as date
        ,s.ga_session_id  as ga_session_id
        ,sp.country as country
        , acs.account_id as account_id
        , a.send_interval
        , a.is_verified
        , a.is_unsubscribed
    FROM `DA.account` a
    JOIN `DA.account_session` acs ON a.id=acs.account_id
    JOIN `DA.session` s ON acs.ga_session_id = s.ga_session_id
    JOIN `DA.session_params` sp ON s.ga_session_id = sp.ga_session_id  
)

-- Calculate account metrics 
, account_metrics AS(
SELECT
    date
    , country
    , send_interval
    , is_verified
    , is_unsubscribed
    , COUNT(DISTINCT account_id) AS account_cnt
FROM  account_session_country
GROUP BY date, country, send_interval, is_verified, is_unsubscribed)

-- Calculate email metrics 
, email_metrics AS (
SELECT
     DATE_ADD(sc.date, INTERVAL sent_date day) AS sent_date
    , sc.country
    , sc.send_interval
    , sc.is_verified
    , sc.is_unsubscribed
    ,COUNT(DISTINCT es.id_message) as sent_msg
    ,COUNT(DISTINCT eo.id_message) as open_msg
    ,COUNT(DISTINCT ev.id_message) as visit_msg  
FROM `DA.email_sent` es
JOIN  account_session_country sc ON es.id_account= sc.account_id
LEFT JOIN `DA.email_open` eo ON es.id_message = eo.id_message
LEFT JOIN `DA.email_visit` ev ON es.id_message = ev.id_message
GROUP BY sent_date, sc.country, sc.send_interval, sc.is_verified, sc.is_unsubscribed)

-- Combine account and email metrics 
, metrics as(
SELECT    
    date
    , country
    , send_interval
    , is_verified
    , is_unsubscribed
    , account_cnt
    ,0 as sent_msg
    ,0 as open_msg
    ,0 as visit_msg
FROM account_metrics
UNION ALL
SELECT    
    sent_date as date
    , country
    , send_interval
    , is_verified
    , is_unsubscribed
    , 0 as account_cnt
    , sent_msg
    , open_msg
    , visit_msg
FROM email_metrics)

-- Aggregate metrics 
, union_metric AS (
SELECT
    date
    , country
    , send_interval
    , is_verified
    , is_unsubscribed
    , SUM(account_cnt) AS account_cnt
    , SUM(sent_msg) AS sent_msg
    , SUM(open_msg) AS open_msg
    , SUM(visit_msg)  AS visit_msg
FROM metrics
GROUP BY date, country, send_interval, is_verified, is_unsubscribed)

-- Calculate total metrics by country 
, union_metrics_with_sum AS (
SELECT *
        ,SUM(account_cnt) OVER(PARTITION BY country) AS total_country_account_cnt
        ,SUM(sent_msg) OVER(PARTITION BY country) AS total_country_sent_msg
FROM union_metric)

-- Calculate country rankings based on total metrics 
, rank_metrics AS (
SELECT *
        , DENSE_RANK() OVER( ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt
        , DENSE_RANK() OVER( ORDER BY total_country_sent_msg DESC) AS rank_total_country_sent_msg
FROM union_metrics_with_sum
)
SELECT *
FROM rank_metrics
WHERE rank_total_country_account_cnt<=10 OR rank_total_country_sent_msg<=10
