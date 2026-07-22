
-- S3 — Gross Revenue Retention and Net Revenue Retention by Cohort
-- Business question: Of the MRR we had from a given monthly cohort 12 months ago, how much did we keep (GRR) and how much INCLUDING expansion (NRR)?
-- What this tells us: Most 2023-2025 cohorts run healthy — GRR typically 65-95%, NRR frequently above 100%
-- (peaking at 127% in Sept 2024), meaning expansion from retained accounts consistently outweighs downgrades.
-- But the May 2025 and June 2025 cohorts collapse sharply — GRR drops to 31.5% and 33.1% respectively, NRR to
-- 37.7% and 48.7% — a dramatic break from the trend. This lines up directly with the churn-MRR spike found in
-- S1 (Jan-March 2026), since these cohorts' 12-month mark falls in that same window.
-- PM Action: Since the May/June 2025 cohort collapse and the S1 churn spike point to the same time window,
-- prioritize investigating what happened company-wide around Jan-March 2026 (pricing change, support quality
-- drop, competitor launch) over treating this as two separate problems — it's very likely one root cause
-- showing up in two different metrics.
-- Sanity check: grr <= 1.0 holds for every cohort (max = 1.0, never exceeded). nrr exceeds 1.0 in multiple
-- cohorts (e.g. 127% in Sept 2024) — confirmed as expected good-news behavior, not a bug. retained_mrr +
-- churn_mrr = starting_mrr holds exactly in every row by construction (churn_mrr recorded as negative).

with first_start as (
    select
        account_id
      , min(event_time) as start_time
    from saas.subscription_events
    where event_type in ('subscription_started', 'trial_converted')
    group by 1
)

, account_starts as (
    select
        fs.account_id
      , date_trunc('month', fs.start_time) as cohort_month
      , fs.start_time
      , se.mrr_delta as starting_mrr
    from first_start fs
    join saas.subscription_events se
        on se.account_id = fs.account_id
       and se.event_time = fs.start_time
       and se.event_type in ('subscription_started', 'trial_converted')
)

, account_churn_check as (
    select
        as_.account_id
      , as_.cohort_month
      , as_.start_time
      , as_.starting_mrr
      , exists (
            select 1 from saas.subscription_events c
            where c.account_id = as_.account_id
              and c.event_type = 'cancelled'
              and c.event_time > as_.start_time
              and c.event_time <= as_.start_time + interval '12 months'
        ) as churned_within_12m
    from account_starts as_
)

, account_movements as (
    select
        acc.account_id
      , sum(se.mrr_delta) filter (
            where se.event_type in ('seat_add', 'addon_attach')
               or (se.event_type = 'plan_changed' and se.mrr_delta > 0)
        ) as expansion_mrr
      , sum(se.mrr_delta) filter (
            where se.event_type = 'plan_changed' and se.mrr_delta < 0
        ) as contraction_mrr
    from account_churn_check acc
    join saas.subscription_events se
        on se.account_id = acc.account_id
       and se.event_time > acc.start_time
       and se.event_time <= acc.start_time + interval '12 months'
       and se.event_type != 'trial_started'
    where acc.churned_within_12m = false
    group by 1
)

select
    acc.cohort_month
  , sum(acc.starting_mrr)                                                              as cohort_starting_mrr
  , sum(case when not acc.churned_within_12m then acc.starting_mrr else 0 end)         as retained_mrr_12m
  , sum(coalesce(am.expansion_mrr, 0))                                                 as expansion_mrr_12m
  , sum(coalesce(am.contraction_mrr, 0))                                               as contraction_mrr_12m
  , sum(case when acc.churned_within_12m then -acc.starting_mrr else 0 end)            as churn_mrr_12m
  , sum(case when not acc.churned_within_12m then acc.starting_mrr else 0 end) * 1.0
        / nullif(sum(acc.starting_mrr), 0)                                             as grr
  , (sum(case when not acc.churned_within_12m then acc.starting_mrr else 0 end)
        + sum(coalesce(am.expansion_mrr, 0))
        + sum(coalesce(am.contraction_mrr, 0))) * 1.0
        / nullif(sum(acc.starting_mrr), 0)                                             as nrr
from account_churn_check acc
left join account_movements am on acc.account_id = am.account_id
where acc.start_time + interval '12 months' <= date '2026-06-15'
group by 1
order by 1;
