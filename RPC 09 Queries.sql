use retail_events_db;


alter table fact_events
add constraint FK_campaigns
foreign key (campaign_id)
references dim_campaigns(campaign_id);

alter table fact_events 
add constraint FK_products
foreign key (product_code)
references dim_products(product_code);



select 
	name as ConstraintName,
	type_desc as ConstraintType
from
	sys.default_constraints
where parent_object_id = OBJECT_ID('fact_events') and 
	  parent_column_id = (
			select column_id
			from sys.columns
			where name = 'store_id' and 
			object_id = OBJECT_ID('fact_events')
);

select 
	max(len(store_id)) as maxLength
from fact_events;





select * from fact_events;

select fe.event_id,
	   fe.store_id,
	   fe.campaign_id,
	   fe.product_code,
	   case
			when fe.promo_type = 'BOGOF' then fe.base_price * 0.5 else fe.base_price 
	   end as adjusted_base_price,
	   fe.promo_type,
	   fe.quantity_sold_before_promo,
	   fe.quantity_sold_after_promo
from fact_events fe;

-- 1. Provide a list of products with a base price greater than 500 and that are featured in the promo type "BOGOF" (Buy One and Get One Free)

SELECT 
	distinct(dp.product_name) as Product
FROM dim_products dp
INNER JOIN fact_events fe ON dp.product_code = fe.product_code
WHERE fe.base_price > 500 AND fe.promo_type = 'BOGOF';

-- 2. Overview of number of stores in each city

select
	city as City,
	count(store_id) as Total_Stores	
from dim_stores
group by City
order by Total_Stores desc;

-- 3. Total revenue before campaign and After campaign.

select  
	ci.campaign_name,
	sum(base_price*quantity_sold_before_promo) as Total_Revenue_Before_Promotion,
	sum(base_price*quantity_sold_after_promo) as Total_Revenue_After_Promotion
from dim_campaigns ci
inner join fact_events f on ci.campaign_id = f.campaign_id
group by ci.campaign_name;

-- 4. Categories listed based on their ISU% and their rankings with respect to the ISU% during Diwali Campaign. 

with ISUTable as (
		select dp.category, 
		sum(f.quantity_sold_after_promo) - sum(f.quantity_sold_before_promo) as ISU,
		100 * (sum(f.quantity_sold_after_promo) - sum(f.quantity_sold_before_promo)) / sum(f.quantity_sold_before_promo) as ISU_Percent
		from dim_products dp
		inner join fact_events f on dp.product_code = f.product_code
		inner join dim_campaigns dc on f.campaign_id = dc.campaign_id
		where dc.campaign_name = 'Diwali'
		group by dp.category
)
select 
	category,
	ISU_Percent,
	rank() over (order by ISU_Percent desc) as Rank_Order
from ISUTable;

-- 5. Top 5 products based on their IR% during campaign sales

create table Top5_IR_Percent (
	Product_Name varchar(255),
	Category varchar(255),
	IR_Percentage decimal(18, 2),
	rank_order int
);

with IR_CTE as (
	select dp.product_name,
		   dp.category,
		   cast(sum(fe.base_price * (fe.quantity_sold_after_promo - fe.quantity_sold_before_promo)) as decimal(18, 2)) as IR,
		   cast(sum(fe.base_price * fe.quantity_sold_before_promo) as decimal(18, 2)) as total_revenue_before_promo
	from dim_products dp
	inner join fact_events fe on dp.product_code = fe.product_code
	group by dp.product_name, dp.category
)
insert into Top5_IR_Percent(Product_Name, Category, IR_Percentage, rank_order)
select 
	product_name,
	category,
	cast(100 * IR / nullif(total_revenue_before_promo, 0) as decimal(18, 2)) as IR_Percent,
    row_number() over (order by 100 * IR / total_revenue_before_promo desc) as rank_order
from 
	IR_CTE;

create index ind on Top5_IR_Percent (IR_Percentage); 

select 
	distinct top 5 * 
from Top5_IR_Percent
order by rank_order; 




