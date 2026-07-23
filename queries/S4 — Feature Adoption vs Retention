-- S4 — Feature Adoption vs Retention
-- Business question: Which product features predict 90-day retention? Which are red herrings?
-- Note on threshold: Brief suggests N=3 as default, but diagnostic showed max observed usage_count in
-- this dataset's first-14-day window is only 2 — N=3 would match zero rows for every feature. Adjusted
-- to N=1 (used at least once in first 14 days), documented as a deliberate deviation.
-- What this tells us: Two structural issues make this dataset weak for detecting real feature-retention
-- signal: (1) baseline 90-day retention is already ~99.8% (near-ceiling, deduped), leaving almost no room
-- for any feature to show a meaningful lift; (2) adoption sample sizes are tiny — the largest is 21 accounts
-- (API Bulk Operations), and several features have just 1-3 adopters, making single-account outcomes
-- pure noise rather than signal.
-- IMPORTANT CAVEAT: This comparison also has a known selection-bias problem — accounts that adopt any
-- feature are likely more engaged overall, so even a real lift would be overstated. Combined with the
-- ceiling effect and tiny samples above, no feature in this result should be treated as a credible driver
-- of retention without a much larger adopter sample.
-- PM Action: Before making any feature-investment decision from this data, prioritize collecting a larger
-- adoption sample over acting on any single feature's lift shown here.
-- Sanity check: accounts_adopted + accounts_not_adopted = total_eligible_accounts (1,193, confirmed).
-- Fixed a subscriptions-join fan-out bug: LEFT JOIN to subscriptions without deduping produced 2,283 rows
-- from 1,193 distinct accounts. Fixed via ROW_NUMBER() picking one (most recent) subscription per account
-- before computing retention. Baseline retention moved from 99.43% (fanned, wrong) to 99.83% (deduped, correct).

with eligible_accounts as (
    select
        a.account_id
      , a.signup_date
    from saas.accounts a
    where a.signup_date <= date '2026-06-15' - interval '90 days'
)

, latest_subscription_per_account as (
    select
        account_id
      , cancelled_at
      , row_number() over (
            partition by account_id
            order by start_date desc
        ) as rn
    from saas.subscriptions
)

, account_retention as (
    select
        ea.account_id
      , ea.signup_date
      , case
            when s.cancelled_at is null
                 or s.cancelled_at > ea.signup_date + interval '90 days'
            then 1 else 0
        end as retained_90d
    from eligible_accounts ea
    left join latest_subscription_per_account s
        on ea.account_id = s.account_id and s.rn = 1
)

, feature_usage_14d as (
    select
        e.account_id
      , e.feature_id
      , count(*) as usage_count
    from saas.events e
    join eligible_accounts ea on e.account_id = ea.account_id
    where e.feature_id is not null
      and e.occurred_at <= ea.signup_date + interval '14 days'
    group by 1, 2
)

, feature_adoption as (
    select
        account_id
      , feature_id
      , case when usage_count >= 1 then 1 else 0 end as adopted
    from feature_usage_14d
)

select
    f.feature_name
  , count(distinct fa.account_id) filter (where fa.adopted = 1)                        as accounts_adopted
  , count(distinct ar.account_id) filter (where fa.adopted is null or fa.adopted = 0)   as accounts_not_adopted
  , avg(ar.retained_90d) filter (where fa.adopted = 1)                                  as retention_rate_adopted
  , avg(ar.retained_90d) filter (where fa.adopted is null or fa.adopted = 0)            as retention_rate_not_adopted
  , (avg(ar.retained_90d) filter (where fa.adopted = 1)
        - avg(ar.retained_90d) filter (where fa.adopted is null or fa.adopted = 0))     as retention_lift_pp
  , (avg(ar.retained_90d) filter (where fa.adopted = 1)
        - avg(ar.retained_90d) filter (where fa.adopted is null or fa.adopted = 0))
        / nullif(avg(ar.retained_90d) filter (where fa.adopted is null or fa.adopted = 0), 0) as retention_lift_pct
from saas.features f
cross join account_retention ar
left join feature_adoption fa on ar.account_id = fa.account_id and f.feature_id = fa.feature_id
group by 1
order by retention_lift_pp desc;
