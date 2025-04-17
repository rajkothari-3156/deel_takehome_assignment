{{ config(materialized='incremental',
          unique_key=['organization_id','transaction_date'],
          order_by='transaction_date',
          incremental_strategy='merge'
          ) }}
with transaction_data as (
    select organization_id,
       date(created_at) as transaction_date,
       sum(case when status in ('credited','refunded') then 1*amount/fx_rate
            when status in ('paid') THEN -1*amount/fx_rate
            else 0 end) as transaction_amount_in_usd
        
from {{source('deel_datasets','invoices')}}
{% if is_incremental() %}
where date(created_at) > (select max(transaction_date) from {{ this }})
{% endif %}
group by 1,2 
),
-- Get historical balances from previous runs
previous_balances AS (
    {% if is_incremental() %}
        SELECT
            organization_id,
            MAX(transaction_date) as last_date,
            SUM(transaction_amount_in_usd) as last_balance
        FROM {{ this }}
        GROUP BY organization_id
    {% else %}
        SELECT
            organization_id,
            NULL as last_date,
            0 as last_balance
        FROM transaction_data
        GROUP BY organization_id
    {% endif %}
),
joined_data AS (
    SELECT
        t.organization_id,
        t.transaction_date,
        t.transaction_amount_in_usd,
        p.last_balance as starting_balance,
        p.last_date
    FROM transaction_data t
    LEFT JOIN previous_balances p ON t.organization_id = p.organization_id
),
-- Calculate running balances
final_result AS (
    SELECT
        organization_id,
        transaction_date,
        transaction_amount_in_usd,
        starting_balance + SUM(transaction_amount_in_usd) OVER (
            PARTITION BY organization_id 
            ORDER BY transaction_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as curr_balance_in_usd
    FROM joined_data
)

SELECT
    organization_id,
    transaction_date,
    transaction_amount_in_usd,
    curr_balance_in_usd,
    curr_balance_in_usd - transaction_amount_in_usd as previous_balance_in_usd,
    case when abs(transaction_amount_in_usd) > 0.5 * abs(curr_balance_in_usd) THEN 1 ELSE 0 END as alert_flag
FROM final_result
ORDER BY organization_id, transaction_date