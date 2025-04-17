# Deel Takehome Assignment - dbt Project

This dbt project contains models and tests for analyzing organization payment data. The project is structured to transform raw data into dimension and fact tables for analysis.

## Project Structure

```
deel_takehome/
├── models/
│   └── silver/
│       ├── dim_organizations.sql
│       ├── fct_organizations_daily_balance.sql
│       └── schema.yml
├── tests/
│   └── generic/
│       └── test_balance_calculation.sql
└── packages.yml
```

## Models

### Dimension Model: `dim_organizations`
A dimension table containing organization information with the following key columns:
- `organization_id` (Primary Key)
- `first_payment_date`
- `created_date`
- `legal_entity_country_code`

### Fact Model: `fct_organizations_daily_balance`
A fact table containing daily balance information for organizations with the following key columns:
- `organization_id` (Foreign Key to dim_organizations)
- `transaction_date`
- `transaction_amount_in_usd`
- `curr_balance_in_usd`
- `previous_balance_in_usd`
- `alert_flag`

## Tests

### Generic Tests
1. `test_balance_calculation`: Validates that current balance equals previous balance plus transaction amount
   ```sql
   curr_balance_in_usd = previous_balance_in_usd + transaction_amount_in_usd
   ```

### Schema Tests
1. For `dim_organizations`:
   - `organization_id`: unique, not_null
   - `first_payment_date`: not_null
   - `created_date`: not_null, must be after first_payment_date

2. For `fct_organizations_daily_balance`:
   - `organization_id`: not_null, relationship to dim_organizations
   - `transaction_date`: not_null, must be before current date
   - `transaction_amount_in_usd`: not_null
   - `curr_balance_in_usd`: not_null
   - `alert_flag`: not_null, must be 0 or 1

## Test Failures

When running `dbt test`, the following failures were observed:

1. **Balance Calculation Test Failure**
   - Error: Current balance does not match the sum of previous balance and transaction amount
   - Impact: Data integrity issue in financial calculations
   - Possible causes:
     - Missing transactions
     - Incorrect balance updates
     - Data synchronization issues

2. **Date Validation Failures**
   - Error: Some transaction dates are in the future
   - Impact: Invalid temporal data
   - Possible causes:
     - Timezone issues
     - Data entry errors
     - System clock synchronization

3. **Referential Integrity Failures**
   - Error: Some organization_ids in fact table don't exist in dimension table

