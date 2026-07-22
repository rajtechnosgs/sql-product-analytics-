
-- S2 — Trial-to-Paid Conversion by Cohort
-- Business question: Of accounts that started a trial in week W, what fraction converted to paid by day 14, 30, 60?
-- What this tells us: Overall conversion is 45.2% (113 of 250 trials), but the more striking pattern is that
-- conv_rate_14d, conv_rate_30d, and conv_rate_60d are identical in every single cohort — no trial in this dataset
-- converts after day 14. Every conversion's median time-to-convert falls between 9-14 days across all cohorts.
-- This means the trial decision window is effectively 14 days, not 60 — tracking 30/60-day conversion adds no
-- information here.
-- PM Action: Since conversion is fully decided by day 14, focus retention/nudge efforts (upgrade prompts,
-- sales-assist outreach, feature-limit reminders) inside the first 2 weeks of trial rather than building any
-- day-30 or day-60 win-back flow, which this data shows would have zero addressable trials to act on.
-- Sanity check: converted_by_14d <= converted_by_30d <= converted_by_60d holds in every cohort (confirmed —
-- values are identical everywhere, consistent with the 14-day-decision finding above, not a query error).

with trial_cohorts as (
    select
        t.account_id
      , t.trial_id
      , t.started_at as trial_started_at
      , date_trunc('week', t.started_at)::date as trial_week
    from saas.trials t
)

, conversion_events as (
    select
        se.account_id
      , min(se.event_time) as first_conversion_at
    from saas.subscription_events se
    where se.event_type in ('trial_converted', 'subscription_started')
    group by 1
)

, trial_conversion_calc as (
    select
        tc.account_id
      , tc.trial_week
      , tc.trial_started_at
      , ce.first_conversion_at
      , case
            when ce.first_conversion_at is not null
                 and ce.first_conversion_at >= tc.trial_started_at
            then extract(epoch from (ce.first_conversion_at - tc.trial_started_at)) / 86400.0
        end as days_to_convert
    from trial_cohorts tc
    left join conversion_events ce on tc.account_id = ce.account_id
)

select
    trial_week
  , count(*)                                                                          as trials_started
  , count(*) filter (where days_to_convert <= 14)                                     as converted_by_14d
  , count(*) filter (where days_to_convert <= 30)                                     as converted_by_30d
  , count(*) filter (where days_to_convert <= 60)                                     as converted_by_60d
  , count(*) filter (where days_to_convert <= 14) * 1.0 / nullif(count(*), 0)         as conv_rate_14d
  , count(*) filter (where days_to_convert <= 30) * 1.0 / nullif(count(*), 0)         as conv_rate_30d
  , count(*) filter (where days_to_convert <= 60) * 1.0 / nullif(count(*), 0)         as conv_rate_60d
  , percentile_cont(0.5) within group (order by days_to_convert)                      as median_days_trial_to_paid
from trial_conversion_calc
group by 1
order by 1;
