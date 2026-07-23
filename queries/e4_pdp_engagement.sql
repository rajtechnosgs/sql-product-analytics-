
-- E4 — PDP Engagement: High-View, Low-Cart Products
-- Business question: Which products attract eyeballs but don't get added to cart?
-- What this tells us: A handful of high-view products underperform their own category median ATC rate
-- by 30+ percentage points — most notably "Silverbirch Vital Hybrid Watch" (1,845 views, only 6.1% ATC,
-- vs. its Smartwatch category median). This isn't a low-traffic problem, it's a conversion problem specific
-- to these SKUs, since category-relative comparison rules out "this category just has low ATC naturally."
-- PM Action: Hand the top 10 flagged SKUs (led by Silverbirch Vital Hybrid Watch, Silverbirch Works Stoneware
-- Coffee French Press, and Indigo Lane Origins Essential Crop Top) to the merchandising PM with three testable
-- hypotheses per product: price positioning vs. category comps, image/listing quality, and stock/size availability
-- at time of view. Start with Silverbirch Vital Hybrid Watch given its 1,845-view volume — any fix there has the
-- largest absolute revenue upside.
-- Sanity check: add_to_cart_sessions <= views for every product (confirmed, 0 violations); atc_rate in [0,1] (confirmed).

with product_views as (
    select
        p.product_id
      , p.product_name
      , c.category_name as category
      , count(*) as views
    from ecom.session_events se
    join ecom.product_variants pv on se.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    join ecom.categories c on c.category_id = p.category_id
    where se.event_type = 'product_view'
    group by 1, 2, 3
)

, product_atc as (
    select
        p.product_id
      , count(distinct se.session_id) as add_to_cart_sessions
    from ecom.session_events se
    join ecom.product_variants pv on se.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    where se.event_type = 'add_to_cart'
    group by 1
)

, product_atc_rates as (
    select
        pv.product_id
      , pv.product_name
      , pv.category
      , pv.views
      , coalesce(pa.add_to_cart_sessions, 0) as add_to_cart_sessions
      , coalesce(pa.add_to_cart_sessions, 0) * 1.0 / nullif(pv.views, 0) as atc_rate
    from product_views pv
    left join product_atc pa on pv.product_id = pa.product_id
)

, category_medians as (
    select
        category
      , percentile_cont(0.5) within group (order by atc_rate) as category_median_atc_rate
    from product_atc_rates
    group by 1
)

select
    par.product_id
  , par.product_name
  , par.category
  , par.views
  , par.add_to_cart_sessions
  , par.atc_rate
  , par.atc_rate - cm.category_median_atc_rate as atc_rate_vs_category_median
  , rank() over (order by par.views desc) as views_rank
  , rank() over (order by par.atc_rate asc) as atc_rate_rank
from product_atc_rates par
join category_medians cm on par.category = cm.category
order by par.views desc;
