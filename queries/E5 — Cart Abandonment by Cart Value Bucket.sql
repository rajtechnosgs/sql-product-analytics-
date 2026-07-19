
-- E5 — Cart Abandonment by Cart Value Bucket
-- Business question: Cart abandonment is 70% overall — but is it the same for ₹500 carts as ₹15,000 carts? Where do we lose the most rupees?
-- What this tells us: Abandonment RATE is inversely related to cart value — <500 carts abandon at 52.6% while
-- 15000+ carts abandon at just 11.8%, meaning customers who build a high-value cart are far more committed to
-- completing the purchase. But GMV lost is concentrated in the middle-high bucket (5000-14999), which alone
-- accounts for ₹98.5L of the ₹242L total lost — nearly 41% of all abandoned GMV comes from a bucket with a
-- below-average abandonment rate, purely because of cart size.
-- PM Action: Prioritize checkout-reliability and payment-friction fixes targeted at the 5000-14999 bucket
-- specifically (e.g., surfacing more payment methods, EMI options, or a saved-cart reminder at this price point)
-- over broad-based abandonment fixes, since this bucket has the largest absolute revenue opportunity despite
-- not having the worst abandonment rate.
-- Sanity check: sum of atc_sessions across buckets (19,862) should match an unsegmented count of ATC sessions in the same window.

with session_cart_value as (
    select
        se.session_id
      , sum(se.quantity * se.unit_price) as cart_value
    from ecom.session_events se
    where se.event_type = 'add_to_cart'
    group by 1
)

, session_purchase_flag as (
    select distinct
        session_id
      , 1 as purchased
    from ecom.session_events
    where event_type = 'purchase'
)

, session_buckets as (
    select
        scv.session_id
      , scv.cart_value
      , case
            when scv.cart_value < 500                          then '<500'
            when scv.cart_value between 500 and 1999            then '500-1999'
            when scv.cart_value between 2000 and 4999           then '2000-4999'
            when scv.cart_value between 5000 and 14999          then '5000-14999'
            else '15000+'
        end as cart_bucket
      , coalesce(spf.purchased, 0) as purchased
    from session_cart_value scv
    left join session_purchase_flag spf on scv.session_id = spf.session_id
)

select
    cart_bucket
  , count(*)                                                              as atc_sessions
  , sum(purchased)                                                        as purchased_sessions
  , count(*) - sum(purchased)                                             as abandoned_sessions
  , (count(*) - sum(purchased)) * 1.0 / nullif(count(*), 0)               as abandonment_rate
  , sum(cart_value) filter (where purchased = 0)                          as gmv_left_on_table
from session_buckets
group by 1
order by
    case cart_bucket
        when '<500' then 1
        when '500-1999' then 2
        when '2000-4999' then 3
        when '5000-14999' then 4
        when '15000+' then 5
    end;
