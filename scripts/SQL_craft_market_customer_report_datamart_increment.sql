WITH
dwh_delta AS (
    SELECT     
        dc.customer_id AS customer_id,
        dc.customer_name AS customer_name,
        dc.customer_address AS customer_address,
        dc.customer_birthday AS customer_birthday,
        dc.customer_email AS customer_email,
        dcr.craftsman_id AS craftsman_id,
        fo.order_id AS order_id,
        dp.product_id AS product_id,
        dp.product_price AS product_price,
        dp.product_type AS product_type,
        fo.order_completion_date - fo.order_created_date AS diff_order_date, 
        fo.order_status AS order_status,
        TO_CHAR(fo.order_created_date, 'yyyy-mm') AS report_period,
        crd.customer_id AS exist_customer_id,
        dc.load_dttm AS customers_load_dttm,
        dp.load_dttm AS products_load_dttm
    FROM dwh.f_order fo 
        INNER JOIN dwh.d_customer dc ON fo.customer_id = dc.customer_id 
        INNER JOIN dwh.d_product dp ON fo.product_id = dp.product_id
        INNER JOIN dwh.d_craftsman dcr ON fo.craftsman_id = dcr.craftsman_id
        LEFT JOIN dwh.customer_report_datamart crd ON dc.customer_id = crd.customer_id
    WHERE (dc.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM dwh.load_dates_customer_report_datamart)) OR
          (dp.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM dwh.load_dates_customer_report_datamart))
),
dwh_update_delta AS (
    SELECT DISTINCT dd.exist_customer_id AS customer_id
    FROM dwh_delta dd 
    WHERE dd.exist_customer_id IS NOT NULL        
),
dwh_delta_insert_result AS (
    SELECT  
        T4.customer_id, T4.customer_name, T4.customer_address, T4.customer_birthday, T4.customer_email,
        T4.customer_money, T4.platform_money, T4.count_order, T4.avg_price_order,
        T4.median_time_order_completed, T4.product_type AS top_product_category, T4.top_craftsman_id,
        T4.count_order_created, T4.count_order_in_progress, T4.count_order_delivery,
        T4.count_order_done, T4.count_order_not_done, T4.report_period 
    FROM (
        SELECT 
            T2.customer_id, T2.customer_name, T2.customer_address, T2.customer_birthday, T2.customer_email,
            T2.customer_money, T2.platform_money, T2.count_order, T2.avg_price_order,
            T2.median_time_order_completed, T3.product_type,
            T5.craftsman_id_for_craftsman AS top_craftsman_id,
            T2.count_order_created, T2.count_order_in_progress, T2.count_order_delivery,
            T2.count_order_done, T2.count_order_not_done, T2.report_period,
            RANK() OVER(PARTITION BY T2.customer_id ORDER BY T3.count_product DESC) AS rank_count_product,
            ROW_NUMBER() OVER(PARTITION BY T2.customer_id ORDER BY T5.count_craftsman DESC, T5.craftsman_id_for_craftsman) AS rn_craftsman
        FROM ( 
            SELECT 
                T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email,
                SUM(T1.product_price) - (SUM(T1.product_price) * 0.1) AS customer_money,
                SUM(T1.product_price) * 0.1 AS platform_money,
                COUNT(order_id) AS count_order,
                AVG(T1.product_price) AS avg_price_order,
                PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY diff_order_date) AS median_time_order_completed,
                SUM(CASE WHEN T1.order_status = 'created' THEN 1 ELSE 0 END) AS count_order_created,
                SUM(CASE WHEN T1.order_status = 'in progress' THEN 1 ELSE 0 END) AS count_order_in_progress, 
                SUM(CASE WHEN T1.order_status = 'delivery' THEN 1 ELSE 0 END) AS count_order_delivery, 
                SUM(CASE WHEN T1.order_status = 'done' THEN 1 ELSE 0 END) AS count_order_done, 
                SUM(CASE WHEN T1.order_status != 'done' THEN 1 ELSE 0 END) AS count_order_not_done,
                T1.report_period
            FROM dwh_delta AS T1
            WHERE T1.exist_customer_id IS NULL
            GROUP BY T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email, T1.report_period
        ) AS T2 
        INNER JOIN (
            SELECT dd.customer_id AS customer_id_for_product_type, dd.product_type, COUNT(dd.product_id) AS count_product
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.product_type
        ) AS T3 ON T2.customer_id = T3.customer_id_for_product_type
        INNER JOIN (
            SELECT dd.customer_id AS customer_id_for_craftsman, dd.craftsman_id AS craftsman_id_for_craftsman, COUNT(dd.order_id) AS count_craftsman
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.craftsman_id
        ) AS T5 ON T2.customer_id = T5.customer_id_for_craftsman
    ) AS T4 
    WHERE T4.rank_count_product = 1 AND T4.rn_craftsman = 1
),
dwh_delta_update_result AS (
    SELECT 
        T4.customer_id, T4.customer_name, T4.customer_address, T4.customer_birthday, T4.customer_email,
        T4.customer_money, T4.platform_money, T4.count_order, T4.avg_price_order,
        T4.median_time_order_completed, T4.product_type AS top_product_category, T4.top_craftsman_id,
        T4.count_order_created, T4.count_order_in_progress, T4.count_order_delivery, 
        T4.count_order_done, T4.count_order_not_done, T4.report_period 
    FROM (
        SELECT 
            T2.customer_id, T2.customer_name, T2.customer_address, T2.customer_birthday, T2.customer_email,
            T2.customer_money, T2.platform_money, T2.count_order, T2.avg_price_order,
            T2.median_time_order_completed, T3.product_type,
            T5.craftsman_id_for_craftsman AS top_craftsman_id,
            T2.count_order_created, T2.count_order_in_progress, T2.count_order_delivery,
            T2.count_order_done, T2.count_order_not_done, T2.report_period,
            RANK() OVER(PARTITION BY T2.customer_id ORDER BY T3.count_product DESC) AS rank_count_product,
            ROW_NUMBER() OVER(PARTITION BY T2.customer_id ORDER BY T5.count_craftsman DESC, T5.craftsman_id_for_craftsman) AS rn_craftsman
        FROM (
            SELECT 
                T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email,
                SUM(T1.product_price) - (SUM(T1.product_price) * 0.1) AS customer_money,
                SUM(T1.product_price) * 0.1 AS platform_money,
                COUNT(order_id) AS count_order,
                AVG(T1.product_price) AS avg_price_order,
                PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY diff_order_date) AS median_time_order_completed,
                SUM(CASE WHEN T1.order_status = 'created' THEN 1 ELSE 0 END) AS count_order_created, 
                SUM(CASE WHEN T1.order_status = 'in progress' THEN 1 ELSE 0 END) AS count_order_in_progress, 
                SUM(CASE WHEN T1.order_status = 'delivery' THEN 1 ELSE 0 END) AS count_order_delivery, 
                SUM(CASE WHEN T1.order_status = 'done' THEN 1 ELSE 0 END) AS count_order_done, 
                SUM(CASE WHEN T1.order_status != 'done' THEN 1 ELSE 0 END) AS count_order_not_done,
                T1.report_period
            FROM (
                SELECT 
                    dc.customer_id, dc.customer_name, dc.customer_address, dc.customer_birthday, dc.customer_email,
                    fo.order_id, dp.product_id, dp.product_price, dp.product_type,
                    fo.order_completion_date - fo.order_created_date AS diff_order_date,
                    fo.order_status, TO_CHAR(fo.order_created_date, 'yyyy-mm') AS report_period
                FROM dwh.f_order fo 
                    INNER JOIN dwh.d_customer dc ON fo.customer_id = dc.customer_id 
                    INNER JOIN dwh.d_product dp ON fo.product_id = dp.product_id
                    INNER JOIN dwh_update_delta ud ON fo.customer_id = ud.customer_id
            ) AS T1
            GROUP BY T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email, T1.report_period
        ) AS T2 
        INNER JOIN (
            SELECT dd.customer_id AS customer_id_for_product_type, dd.product_type, COUNT(dd.product_id) AS count_product
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.product_type
        ) AS T3 ON T2.customer_id = T3.customer_id_for_product_type
        INNER JOIN (
            SELECT dd.customer_id AS customer_id_for_craftsman, dd.craftsman_id AS craftsman_id_for_craftsman, COUNT(dd.order_id) AS count_craftsman
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.craftsman_id
        ) AS T5 ON T2.customer_id = T5.customer_id_for_craftsman
    ) AS T4 
    WHERE T4.rank_count_product = 1 AND T4.rn_craftsman = 1
),
insert_delta AS (
    INSERT INTO dwh.customer_report_datamart (
        customer_id, customer_name, customer_address, customer_birthday, customer_email, 
        customer_money, platform_money, count_order, avg_price_order, 
        median_time_order_completed, top_product_category, top_craftsman_id,
        count_order_created, count_order_in_progress, count_order_delivery, 
        count_order_done, count_order_not_done, report_period
    ) SELECT 
        customer_id, customer_name, customer_address, customer_birthday, customer_email, 
        customer_money, platform_money, count_order, avg_price_order, 
        median_time_order_completed, top_product_category, top_craftsman_id,
        count_order_created, count_order_in_progress, count_order_delivery, 
        count_order_done, count_order_not_done, report_period 
    FROM dwh_delta_insert_result
),
update_delta AS (
    UPDATE dwh.customer_report_datamart SET
        customer_name = updates.customer_name, 
        customer_address = updates.customer_address, 
        customer_birthday = updates.customer_birthday, 
        customer_email = updates.customer_email, 
        customer_money = updates.customer_money, 
        platform_money = updates.platform_money, 
        count_order = updates.count_order, 
        avg_price_order = updates.avg_price_order, 
        median_time_order_completed = updates.median_time_order_completed, 
        top_product_category = updates.top_product_category, 
        top_craftsman_id = updates.top_craftsman_id,
        count_order_created = updates.count_order_created, 
        count_order_in_progress = updates.count_order_in_progress, 
        count_order_delivery = updates.count_order_delivery, 
        count_order_done = updates.count_order_done,
        count_order_not_done = updates.count_order_not_done, 
        report_period = updates.report_period
    FROM (
        SELECT 
            customer_id, customer_name, customer_address, customer_birthday, customer_email, 
            customer_money, platform_money, count_order, avg_price_order, 
            median_time_order_completed, top_product_category, top_craftsman_id,
            count_order_created, count_order_in_progress, count_order_delivery, 
            count_order_done, count_order_not_done, report_period 
        FROM dwh_delta_update_result
    ) AS updates
    WHERE dwh.customer_report_datamart.customer_id = updates.customer_id
),
insert_load_date AS (
    INSERT INTO dwh.load_dates_customer_report_datamart (load_dttm)
    SELECT GREATEST(
        COALESCE(MAX(customers_load_dttm), NOW()), 
        COALESCE(MAX(products_load_dttm), NOW())
    ) 
    FROM dwh_delta
)
SELECT 'increment customer datamart';
