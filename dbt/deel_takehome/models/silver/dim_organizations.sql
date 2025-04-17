-- Dim table will only contain the fields that hardly change over time

{{ config(materialized='incremental',
        unique_key='organization_id',
        order_by='created_date',
        incremental_strategy='merge') }}

select organization_id,
    first_payment_date,
    legal_entity_country_code,
    created_date
from {{ source('deel_datasets', 'organizations') }}
{% if is_incremental() %}
where created_date > (select max(created_date) from {{ this }})
{% endif %}