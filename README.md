Шаг 2. Изучение данных нового источника
Перед написанием скрипта нужно изучить структуры таблиц:
sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'external_source' AND table_name = 'craft_products_orders'
ORDER BY ordinal_position;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'external_source' AND table_name = 'customers'
ORDER BY ordinal_position;
Шаг 3. Дополненный скрипт загрузки
/* создание таблицы tmp_sources с данными из всех источников */
DROP TABLE IF EXISTS tmp_sources;

CREATE TEMP TABLE tmp_sources AS 
SELECT  order_id,
        order_created_date,
        order_completion_date,
        order_status,
        craftsman_id,
        craftsman_name,
        craftsman_address,
        craftsman_birthday,
        craftsman_email,
        product_id,
        product_name,
        product_description,
        product_type,
        product_price,
        customer_id,
        customer_name,
        customer_address,
        customer_birthday,
        customer_email 
FROM source1.craft_market_wide

UNION

SELECT  t2.order_id,
        t2.order_created_date,
        t2.order_completion_date,
        t2.order_status,
        t1.craftsman_id,
        t1.craftsman_name,
        t1.craftsman_address,
        t1.craftsman_birthday,
        t1.craftsman_email,
        t1.product_id,
        t1.product_name,
        t1.product_description,
        t1.product_type,
        t1.product_price,
        t2.customer_id,
        t2.customer_name,
        t2.customer_address,
        t2.customer_birthday,
        t2.customer_email 
FROM source2.craft_market_masters_products t1 
JOIN source2.craft_market_orders_customers t2 
    ON t2.product_id = t1.product_id 
    AND t1.craftsman_id = t2.craftsman_id 

UNION

SELECT  t1.order_id,
        t1.order_created_date,
        t1.order_completion_date,
        t1.order_status,
        t2.craftsman_id,
        t2.craftsman_name,
        t2.craftsman_address,
        t2.craftsman_birthday,
        t2.craftsman_email,
        t1.product_id,
        t1.product_name,
        t1.product_description,
        t1.product_type,
        t1.product_price,
        t3.customer_id,
        t3.customer_name,
        t3.customer_address,
        t3.customer_birthday,
        t3.customer_email
FROM source3.craft_market_orders t1
JOIN source3.craft_market_craftsmans t2 
    ON t1.craftsman_id = t2.craftsman_id 
JOIN source3.craft_market_customers t3 
    ON t1.customer_id = t3.customer_id

UNION

SELECT  t1.order_id,
        t1.order_created_date,
        t1.order_completion_date,
        t1.order_status,
        t1.craftsman_id,
        t1.craftsman_name,
        t1.craftsman_address,
        t1.craftsman_birthday,
        t1.craftsman_email,
        t1.product_id,
        t1.product_name,
        t1.product_description,
        t1.product_type,
        t1.product_price,
        t2.customer_id,
        t2.customer_name,
        t2.customer_address,
        t2.customer_birthday,
        t2.customer_email
FROM external_source.craft_products_orders t1
JOIN external_source.customers t2 
    ON t1.customer_id = t2.customer_id;

Шаг 4. Анализ потребностей бизнеса
Требуемые данные для витрины customer_report_datamart:
№	Поле	Описание	Аналог в витрине по мастерам
1	id	идентификатор записи	id
2	customer_id	идентификатор заказчика	craftsman_id
3	customer_name	Ф.И.О. заказчика	craftsman_name
4	customer_address	адрес заказчика	craftsman_address
5	customer_birthday	дата рождения	craftsman_birthday
6	customer_email	email заказчика	craftsman_email
7	customer_money	сумма, потраченная заказчиком	craftsman_money
8	platform_money	10% от суммы заказчика	platform_money
9	count_order	количество заказов за месяц	count_order
10	avg_price_order	средняя стоимость заказа	avg_price_order
11	median_time_order_completed	медианное время выполнения	median_time_order_completed
12	top_product_category	популярная категория товаров	top_product_category
13	top_craftsman_id	ID самого популярного мастера	НОВОЕ ПОЛЕ
14	count_order_created	созданных заказов	count_order_created
15	count_order_in_progress	в процессе изготовки	count_order_in_progress
16	count_order_delivery	в доставке	count_order_delivery
17	count_order_done	завершённых	count_order_done
18	count_order_not_done	незавершённых	count_order_not_done
19	report_period	отчётный период	report_period
Ключевое отличие: добавлено поле top_craftsman_id — ID самого популярного мастера у заказчика.
Шаг 5. Напишите DDL новой витрины
DROP TABLE IF EXISTS dwh.customer_report_datamart;

CREATE TABLE IF NOT EXISTS dwh.customer_report_datamart (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL,
    customer_name VARCHAR NOT NULL,
    customer_address VARCHAR NOT NULL,
    customer_birthday DATE NOT NULL,
    customer_email VARCHAR NOT NULL,
    customer_money NUMERIC(10, 2) NOT NULL,
    platform_money NUMERIC(10, 2) NOT NULL,
    count_order BIGINT NOT NULL,
    avg_price_order NUMERIC(10, 2) NOT NULL,
    median_time_order_completed NUMERIC(10, 1) NULL,
    top_product_category VARCHAR NOT NULL,
    top_craftsman_id BIGINT NOT NULL,
    count_order_created BIGINT NOT NULL,
    count_order_in_progress BIGINT NOT NULL,
    count_order_delivery BIGINT NOT NULL,
    count_order_done BIGINT NOT NULL,
    count_order_not_done BIGINT NOT NULL,
    report_period VARCHAR NOT NULL,
    CONSTRAINT customer_report_datamart_pk PRIMARY KEY (id)
);

-- Комментарии к колонкам
COMMENT ON TABLE dwh.customer_report_datamart IS 'Инкрементальная витрина по заказчикам ручной работы';
COMMENT ON COLUMN dwh.customer_report_datamart.id IS 'Идентификатор записи';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_id IS 'Идентификатор заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_name IS 'Ф.И.О. заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_address IS 'Адрес заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_birthday IS 'Дата рождения заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_email IS 'Электронная почта заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.customer_money IS 'Сумма, которую потратил заказчик';
COMMENT ON COLUMN dwh.customer_report_datamart.platform_money IS 'Сумма, которую заработала платформа (10% от суммы заказчика)';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order IS 'Количество заказов у заказчика за месяц';
COMMENT ON COLUMN dwh.customer_report_datamart.avg_price_order IS 'Средняя стоимость одного заказа';
COMMENT ON COLUMN dwh.customer_report_datamart.median_time_order_completed IS 'Медианное время в днях от создания до завершения заказа';
COMMENT ON COLUMN dwh.customer_report_datamart.top_product_category IS 'Самая популярная категория товаров у заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.top_craftsman_id IS 'Идентификатор самого популярного мастера у заказчика';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order_created IS 'Количество созданных заказов за месяц';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order_in_progress IS 'Количество заказов в процессе изготовки';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order_delivery IS 'Количество заказов в доставке';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order_done IS 'Количество завершённых заказов';
COMMENT ON COLUMN dwh.customer_report_datamart.count_order_not_done IS 'Количество незавершённых заказов';
COMMENT ON COLUMN dwh.customer_report_datamart.report_period IS 'Отчётный период (год и месяц)';

-- Индексы для ускорения поиска
CREATE INDEX idx_customer_report_datamart_customer_id 
    ON dwh.customer_report_datamart(customer_id);
CREATE INDEX idx_customer_report_datamart_report_period 
    ON dwh.customer_report_datamart(report_period);
CREATE INDEX idx_customer_report_datamart_customer_period 
    ON dwh.customer_report_datamart(customer_id, report_period);


Шаг 6. Напишите скрипт для инкрементального обновления витрины


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



