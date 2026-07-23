
-- E1 — Activation Curve: Time-to-First-Meaningful-Action
-- Business question: How fast do new signups become real users, and how has that changed cohort-over-cohort?
-- What this tells us: Activation rate has collapsed from 16.3% (April 13 cohort) to 4.3% (June 1 cohort) — 
-- and this isn't a censoring artifact, since both cohorts' 7-day windows have fully closed within the data. 
-- Median time-to-activation for those who do activate stays fairly stable (~4,000-4,800 minutes, ~3 days), 
-- so this isn't a "people are slower to activate" problem — it's a "fewer people activate at all" problem.
-- PM Action: Investigate what changed around late April/early May (new acquisition channel, onboarding change, 
-- or traffic-quality shift) that coincides with activation dropping from ~12% to ~5% across the May cohorts — 
-- this is a bigger lever than any UX tweak to the activation flow itself.
-- Sanity check: activated_7d <= cohort_size on every row (confirmed). Most recent cohort (June 8) partially censored.

with customer_first_action as (
    select
        c.customer_id
      , date_trunc('week', c.created_at)::date as signup_week
      , c.created_at                            as signup_at
      , min(se.occurred_at) filter (
            where se.event_type in ('add_to_cart', 'begin_checkout', 'purchase')
        )                                        as first_meaningful_action_at
    from ecom.customers c
    left join ecom.sessions s on c.customer_id = s.customer_id
    left join ecom.session_events se on s.session_id = se.session_id
    where c.created_at >= '2026-04-19'
    group by 1, 2, 3
)

, activation_calc as (
    select
        customer_id
      , signup_week
      , first_meaningful_action_at
      , case
            when first_meaningful_action_at is not null
                 and first_meaningful_action_at >= signup_at
                 and first_meaningful_action_at <= signup_at + interval '7 days'
            then 1 else 0
        end as activated_7d
      , case
            when first_meaningful_action_at is not null
                 and first_meaningful_action_at >= signup_at
                 and first_meaningful_action_at <= signup_at + interval '7 days'
            then extract(epoch from (first_meaningful_action_at - signup_at)) / 60.0
        end as minutes_to_activation
    from customer_first_action
)

select
    signup_week
  , count(*)                                                              as cohort_size
  , sum(activated_7d)                                                     as activated_7d
  , sum(activated_7d) * 1.0 / nullif(count(*), 0)                        as activation_rate_7d
  , percentile_cont(0.5) within group (order by minutes_to_activation)    as median_minutes_to_activation
  , percentile_cont(0.9) within group (order by minutes_to_activation)    as p90_minutes_to_activation
from activation_calc
group by 1
order by 1;
