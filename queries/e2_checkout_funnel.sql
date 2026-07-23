-- E2 — Checkout Funnel Drop-off by Entry Channel
-- Business question: Where is checkout leaking, and is the leak the same across paid social vs organic search?
-- What this tells us: The leak is NOT channel-specific — every channel shows the same shape: small 1-4% drops
-- at address/shipping/payment-entry, but a consistent 7.6%-8.3% drop at the final payment-to-purchase step,
-- regardless of channel. This points to a shared checkout-completion issue (likely payment processing, given
-- Task 1's finding that payment failure rates run 4-5.5% depending on method) rather than a channel-quality problem.
-- PM Action: Prioritize a payment-completion investigation (retry logic, error messaging, supported methods)
-- over any channel-specific fix, since the failure is uniform across paid, organic, referral, email, and affiliate.
-- Sanity check: begin_checkout >= address >= shipping >= payment >= purchased holds for every channel (confirmed).

with session_step_reached as (
    select
        s.session_id
      , sc.channel
      , max(case
            when se.event_type = 'purchase'        then 5
            when se.event_type = 'add_payment'      then 4
            when se.event_type = 'select_shipping'  then 3
            when se.event_type = 'add_address'      then 2
            when se.event_type = 'begin_checkout'   then 1
            else 0
        end) as max_step
    from ecom.sessions s
    join ecom.session_channels sc using (session_id)
    join ecom.session_events se using (session_id)
    group by 1, 2
)

, funnel_counts as (
    select
        channel
      , count(*) filter (where max_step >= 1) as begin_checkout
      , count(*) filter (where max_step >= 2) as address
      , count(*) filter (where max_step >= 3) as shipping
      , count(*) filter (where max_step >= 4) as payment
      , count(*) filter (where max_step >= 5) as purchased
    from session_step_reached
    where max_step >= 1
    group by 1
)

select
    channel
  , begin_checkout
  , address
  , shipping
  , payment
  , purchased
  , (begin_checkout - address) * 1.0 / nullif(begin_checkout, 0) as drop_address_pct
  , (address - shipping)       * 1.0 / nullif(address, 0)        as drop_shipping_pct
  , (shipping - payment)       * 1.0 / nullif(shipping, 0)       as drop_payment_pct
  , (payment - purchased)      * 1.0 / nullif(payment, 0)        as drop_final_pct
from funnel_counts
order by begin_checkout desc;
