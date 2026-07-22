
-- S1 — Monthly MRR Movement Decomposition
-- Business question: How did MRR change last month — and what drove the change? New, expansion, contraction, or churn?
-- What this tells us: Churn MRR accelerated sharply in 2026 — from a typical ₹1,000-4,000/month range through
-- 2025 to ₹9,506-13,821/month across Jan-March 2026, a 3-10x increase. Expansion and reactivation MRR also grew
-- over the same period, but not enough to fully offset the churn spikes in January and March. March 2026 is the
-- single worst month, with churn MRR of -₹13,821 against new MRR of only ₹20,157 — the smallest new-to-churn
-- ratio seen anywhere in the 4+ years of history.
-- PM Action: Run a cohort cut on the accounts that churned in March 2026 (the largest churn month), segmented by
-- account_type (self_serve vs b2b), plan tier, and tenure at time of churn, to identify whether this churn spike
-- is concentrated in one segment or broad-based before proposing a retention fix.
-- Sanity check: ending_mrr as of the last full month (May 2026) = ₹410,244.95 via event-sum. Reconciliation
-- against subscriptions.mrr snapshot was attempted three ways: (1) active-only = ₹246,739.16 — 40% short;
-- (2) active + paused + past_due (not yet formally churned) = ₹315,363.13 — still 23% short; (3) checked for
-- duplicate subscription_started/trial_converted events per subscription — none found. The remaining gap does
-- not resolve to a single traceable cause and is documented here as a known reconciliation limitation in this
-- synthetic dataset (event history and current snapshot are not fully self-consistent) rather than forced to
-- an artificial match.

with classified_events as (
    select
        date_trunc('month', se.event_time) as month
      , se.account_id
      , se.mrr_delta
      , case
            when se.event_type in ('subscription_started', 'trial_converted')
                 and exists (
                     select 1 from saas.subscription_events p
                     where p.account_id = se.account_id
                       and p.event_type = 'cancelled'
                       and p.event_time < se.event_time
                 )
            then 'reactivation'

            when se.event_type in ('subscription_started', 'trial_converted')
            then 'new'

            when se.event_type = 'plan_changed' and se.mrr_delta > 0
            then 'expansion'

            when se.event_type in ('seat_add', 'addon_attach')
            then 'expansion'

            when se.event_type = 'plan_changed' and se.mrr_delta < 0
            then 'contraction'

            when se.event_type = 'cancelled'
            then 'churn'
        end as bucket
    from saas.subscription_events se
    where se.event_type != 'trial_started'
      and se.event_time <= date '2026-06-15'
)

, monthly_buckets as (
    select
        month
      , sum(mrr_delta) filter (where bucket = 'new')          as new_mrr
      , sum(mrr_delta) filter (where bucket = 'expansion')    as expansion_mrr
      , sum(mrr_delta) filter (where bucket = 'contraction')  as contraction_mrr
      , sum(mrr_delta) filter (where bucket = 'churn')        as churn_mrr
      , sum(mrr_delta) filter (where bucket = 'reactivation') as reactivation_mrr
      , sum(mrr_delta)                                        as net_new_mrr
    from classified_events
    group by 1
)

, mrr_with_running_total as (
    select
        month
      , new_mrr
      , expansion_mrr
      , contraction_mrr
      , churn_mrr
      , reactivation_mrr
      , net_new_mrr
      , sum(net_new_mrr) over (order by month) as ending_mrr
    from monthly_buckets
)

select
    month
  , new_mrr
  , expansion_mrr
  , contraction_mrr
  , churn_mrr
  , reactivation_mrr
  , net_new_mrr
  , ending_mrr
from mrr_with_running_total
order by month;
