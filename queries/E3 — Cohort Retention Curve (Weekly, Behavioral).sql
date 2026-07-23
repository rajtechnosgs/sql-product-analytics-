
-- E3 — Cohort Retention Curve (Weekly, Behavioral)
-- Business question: Of users who signed up in week W, what fraction came back and did something meaningful in week W+1, W+2, W+3, W+4?
-- What this tells us: [fill in after seeing result]
-- PM Action: [fill in after seeing result]
-- Sanity check: w0_active should equal the count of customers with ANY meaningful session ever
-- (5,751 of 6,267 in this dataset) after clipping pre-signup activity into week 0 — see data-quality note.




with customer_signups as (
    select
        customer_id
      , created_at as signup_at
      , date_trunc('week', created_at)::date as cohort_week
    from ecom.customers
    where created_at >= '2026-04-19'
)

, meaningful_sessions as (
    select distinct
        s.customer_id
      , s.session_id
      , se.occurred_at
    from ecom.sessions s
    join ecom.session_events se on s.session_id = se.session_id
    where se.event_type in ('product_view', 'add_to_cart', 'purchase')
)

, customer_activity_weeks as (
    select
        cs.customer_id
      , cs.cohort_week
      , greatest(
            floor(extract(epoch from (ms.occurred_at - cs.signup_at)) / (86400 * 7))
          , 0
        ) as week_index
    from customer_signups cs
    left join meaningful_sessions ms on cs.customer_id = ms.customer_id
)

select
    cs.cohort_week
  , count(distinct cs.customer_id) as cohort_size
  , count(distinct caw.customer_id) filter (where caw.week_index = 0) as w0_active
  , count(distinct caw.customer_id) filter (where caw.week_index = 1) as w1_retained
  , count(distinct caw.customer_id) filter (where caw.week_index = 2) as w2_retained
  , count(distinct caw.customer_id) filter (where caw.week_index = 3) as w3_retained
  , count(distinct caw.customer_id) filter (where caw.week_index = 4) as w4_retained
  , count(distinct caw.customer_id) filter (where caw.week_index = 1) * 1.0
        / nullif(count(distinct cs.customer_id), 0) as w1_retention_rate
  , count(distinct caw.customer_id) filter (where caw.week_index = 2) * 1.0
        / nullif(count(distinct cs.customer_id), 0) as w2_retention_rate
  , count(distinct caw.customer_id) filter (where caw.week_index = 3) * 1.0
        / nullif(count(distinct cs.customer_id), 0) as w3_retention_rate
  , count(distinct caw.customer_id) filter (where caw.week_index = 4) * 1.0
        / nullif(count(distinct cs.customer_id), 0) as w4_retention_rate
from customer_signups cs
left join customer_activity_weeks caw on cs.customer_id = caw.customer_id
group by 1
order by 1;
