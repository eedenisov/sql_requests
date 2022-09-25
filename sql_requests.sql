DROP TABLE sales;
DROP TABLE dep;
DROP TABLE prod;

-- есть три очень условные таблицы:

-- отделы
CREATE TABLE dep
(
    id   integer NOT NULL,
    city text    NOT NULL,
    name text    NOT NULL,
    CONSTRAINT dep_pk PRIMARY KEY (id)
);

-- продукты
CREATE TABLE prod
(
    id    integer NOT NULL,
    price integer NOT NULL,
    name  text    NOT NULL,
    CONSTRAINT prod_pk PRIMARY KEY (id)
);

-- продажи
CREATE TABLE sales
(
    time    timestamp      NOT NULL,
    dep_id  integer        NOT NULL,
    prod_id integer        NOT NULL,
    cost    numeric(10, 2) NOT NULL,
    CONSTRAINT sales_fk1 FOREIGN KEY (dep_id) REFERENCES dep (id),
    CONSTRAINT sales_fk2 FOREIGN KEY (prod_id) REFERENCES prod (id)
);
commit;

-- для тестирования можно так заполнить
INSERT INTO dep
select i,
       CASE
           WHEN i <= 50 THEN 'town1'
           ELSE 'town2'
           END,
       'dep'
           || i::text
from generate_series(1, 100) as i;

INSERT INTO prod
select i,
       i * 10,
       'prod'
           || i::text
from generate_series(1, 100) as i;


INSERT INTO sales
select timestamp '2021-01-01 00:00' + interval '1 day' * random() - interval '1 day' * i,
       mod(i, 100) + 1,
       mod(i, 100) + 1,
       i
from generate_series(1, 1000) as i;
COMMIT;

-- 1. получить все продажи произведенные в городе 'town1' за 2019 год
with dep_city as (select id, city, name
                  from dep
                  where city = 'town1'),
     sales_by_year as (select cost, time, dep_id, prod_id from sales where extract(YEAR from time) = '2019')
select t2.cost, t1.city, t2.time, t3.price, t1.name as "dep_name", t3.name as "prod_name"
from dep_city t1
         join sales_by_year t2 on t1.id = t2.dep_id
         join prod t3 on t3.id = t2.prod_id
order by time;

-- 2. показать все отделы, где в марте 2020 года были продажи товаров с ценой (sales.cost) меньше 500.
with sales_by_year as (select cost, time, dep_id, prod_id
                       from sales
                       where extract(YEAR from time) = '2020'
                         and extract(MONTH from time) = '03'
                         and cost < 500)
select t1.name, t2.cost, t2.time
from sales_by_year t2
         join dep t1 on dep_id = t1.id
order by cost;

-- 3. увеличить значение цены (prod.price)  в таблице в два раза у всех товаров, которые продавались в 2018 году в отделе 'dep10'
with dep_10 as (select id, name
                from dep
                where name = 'dep10'),
     sales_by_time as (select time, dep_id, prod_id from sales where extract(YEAR from time) = '2018'),
     dep_sales_prod as (select t1.name as "dep_name", t2.time, t3.price, t3.name as "prod_name"
                        from dep_10 t1
                                 join sales_by_time t2 on t1.id = t2.dep_id
                                 join prod t3 on t3.id = t2.prod_id)
update prod
set price = price * 2;

-- проверка результатов по 3 запросу
with dep_10 as (select id, name
                from dep
                where name = 'dep10'),
     sales_by_time as (select time, dep_id, prod_id from sales where extract(YEAR from time) = '2018')
select t1.name as "dep_name", t2.time, t3.price, t3.name as "prod_name"
from dep_10 t1
         join sales_by_time t2 on t1.id = t2.dep_id
         join prod t3 on t3.id = t2.prod_id;

-- 4. составить сводный отчет по суммарной стоимости товаров проданных в городе 'town1'
create extension if not exists tablefunc;
create view report as
Select year,
       sum("1")  as "Jan",
       sum("2")  as "Feb",
       sum("3")  as "Mar",
       sum("4")  as "Apr",
       sum("5")  as "May",
       sum("6")  as "Jun",
       sum("7")  as "Jul",
       sum("8")  as "Aug",
       sum("9")  as "Sep",
       sum("10") as "Oct",
       sum("11") as "Nov",
       sum("12") as "Dec"
from (select year
           , coalesce("1", 0)  as "1"
           , coalesce("2", 0)  as "2"
           , coalesce("3", 0)  as "3"
           , coalesce("4", 0)  as "4"
           , coalesce("5", 0)  as "5"
           , coalesce("6", 0)  as "6"
           , coalesce("7", 0)  as "7"
           , coalesce("8", 0)  as "8"
           , coalesce("9", 0)  as "9"
           , coalesce("10", 0) as "10"
           , coalesce("11", 0) as "11"
           , coalesce("12", 0) as "12"
      from (select *
            from crosstab(
                         $$with
     dep_city as (select id, city
                  from dep
                  where city = 'town1'),
     sales_by_time as (select time, cost, dep_id, prod_id
                       from sales
                       where time between
                       to_date('2018-01-01', 'YYYY-MM-DD') and to_date('2020-12-31', 'YYYY-MM-DD')),
     dep_sales as (select t1.city, t2.time as "year", t2.time as "month", t2.cost
                   from dep_city t1
                            join sales_by_time t2 on t1.id = t2.dep_id)
     select extract(YEAR from year),
            extract(MONTH from month),
            sum("cost") as "Cost"
                  from dep_sales
                  group by 1,2$$, $$select m from generate_series (1,12) m$$
                     ) as (year double precision, "1" double precision, "2" double precision, "3" double precision,
                           "4" double precision, "5" double precision, "6" double precision, "7" double precision,
                           "8" double precision, "9" double precision, "10" double precision, "11" double precision,
                           "12" double precision)) t) t1
group by year
order by year;