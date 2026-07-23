-- S5 — Expansion Revenue: Who's Upgrading and Why
-- Business question: Of accounts that expanded MRR in the last 6 months, what's the dominant expansion vector — seats added, plan upgrade, or add-on attach?
-- What this tells us: seats_added drives the most total expansion revenue (₹7,662, 42 events) and the highest
-- per-account value (₹225), even though plan_upgrade touches more accounts (57 vs 34). Add-on attach is
-- negligible in this window (3 events, ₹262 total) — not yet a meaningful expansion motion.
-- PM Action: Invest in seat-management UX and admin-facing seat-add flows first — it has the highest
-- per-account revenue impact, meaning small UX friction reductions here compound across the largest dollar
-- value. Plan_upgrade prompts remain a secondary priority given their broader account reach but lower
-- per-account value; deprioritize add-on cross-sell investment until adoption volume grows.
-- Sanity check: expansion_mrr_total (₹14,272.60, exact 6-month rolling window) vs S1's calendar-month
-- expansion_mrr summed over the same period (₹15,365.75, Dec 2025 - June 2026) — off by ~7%, explained by
-- the window-boundary mismatch (S1 uses full calendar months; S5 uses an exact rolling 6-month cutoff from
-- 2026-06-15, excluding the first 14 days of December). Not an exact match, but the gap is fully explained
-- by this documented methodology difference, not a misclassification bug.

with expansion_events as (
    select
        se.account_id
      , se.event_time
      , se.mrr_delta
      , se.seats_delta
      , case
            when se.event_type = 'seat_add' then 'seats_added'
            when se.event_type = 'addon_attach' then 'addon'
            when se.event_type = 'plan_changed' and se.mrr_delta > 0 then 'plan_upgrade'
        end as expansion_type
    from saas.subscription_events se
    where (
            se.event_type in ('seat_add', 'addon_attach')
            or (se.event_type = 'plan_changed' and se.mrr_delta > 0)
          )
      and se.event_time >= date '2026-06-15' - interval '6 months'
      and se.event_time <= date '2026-06-15'
)

, expansion_with_signup as (
    select
        ee.account_id
      , ee.expansion_type
      , ee.mrr_delta
      , ee.event_time
      , a.signup_date
      , extract(epoch from (ee.event_time - a.signup_date)) / 86400.0 as days_from_signup
    from expansion_events ee
    join saas.accounts a on ee.account_id = a.account_id
)

select
    expansion_type
  , count(*)                                                        as expansion_events
  , count(distinct account_id)                                      as accounts_expanded
  , sum(mrr_delta)                                                  as expansion_mrr_total
  , sum(mrr_delta) * 1.0 / nullif(count(distinct account_id), 0)    as expansion_mrr_per_account
  , percentile_cont(0.5) within group (order by days_from_signup)   as median_days_from_signup_to_expansion
from expansion_with_signup
group by 1
order by expansion_mrr_total desc;
