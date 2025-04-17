import pandas as pd
import requests
import json
from datetime import datetime
import os
import snowflake.connector
from snowflake.connector.cursor import SnowflakeCursor
import os


def get_snowflake_connection():
    conn = snowflake.connector.connect(
        user='rajkothari',
        password=os.environ.get('SNOWFLAKE_DEEL_PASSWORD'),
        account='xduamzf-vb71832',
        warehouse='COMPUTE_WH',
        database='RAWDATA_DB',
        schema='TRANSACTIONS',
        role='DBT_ROLE'
    )
    return conn

def fetch_data_from_snowflake(query, conn):
    cursor = conn.cursor()
    cursor.execute(query)
    column_names = [desc[0] for desc in cursor.description]
    return pd.DataFrame(cursor.fetchall(), columns=column_names)

def close_snowflake_connection(conn):
    conn.close()

def format_alert_message(data: pd.DataFrame) -> str:
    """
    Format the alert data into a readable Slack message
    """
    message = "*🚨 Deel High Value Transaction Alert*\n\n"
    
    # Group by organization and date
    grouped_data = data.groupby(['ORGANIZATION_ID', 'TRANSACTION_DATE'])
    
    for (org_id, date), group in grouped_data:
        message += f"*Organization ID:* {org_id}\n"
        message += f"*Date:* {date}\n"
        
        for _, row in group.iterrows():
            # Escape special characters and ensure proper formatting
            message += (f"• Transaction Amount: ${row['TRANSACTION_AMOUNT_IN_USD']:,.2f}\n"
                       f"  Current Balance: ${row['CURR_BALANCE_IN_USD']:,.2f}\n"
                       f"  Previous Balance: ${row['PREVIOUS_BALANCE_IN_USD']:,.2f}\n")
        
        message += "\n"
    
    # Truncate message if too long (Slack has a 40k character limit)
    if len(message) > 39000:
        message = message[:39000] + "\n\n*Message truncated due to length*"
        
    return message

def send_slack_alert(webhook_url: str, message: str) -> bool:
    """
    Send the alert message to Slack
    """
    # Split message into chunks if needed (Slack's limit is around 40k characters)
    max_length = 39000
    messages = [message[i:i+max_length] for i in range(0, len(message), max_length)]
    
    success = True
    for msg in messages:
        payload = {
            "blocks": [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": msg
                    }
                }
            ]
        }
        
        try:
            response = requests.post(
                webhook_url,
                data=json.dumps(payload),
                headers={'Content-Type': 'application/json'}
            )
            if response.status_code != 200:
                success = False
                break
        except Exception as e:
            print(f"Error sending Slack message: {str(e)}")
            success = False
            break
            
    return success

def main():
    # Get webhook URL from environment variable
    webhook_url = os.environ.get('DEEL_INCOMING_WEBHOOK_URL')
    
    if not webhook_url:
        print("Error: DEEL_INCOMING_WEBHOOK_URL environment variable not set")
        return
    
    # Connect to Snowflake and fetch data
    conn = get_snowflake_connection()
    data = fetch_data_from_snowflake("select * from dev_db.analytics.fct_organizations_daily_balance where transaction_date >= current_date() - interval '360 day' and alert_flag = 1 and previous_balance_in_usd != 0", conn)
    close_snowflake_connection(conn)
    
    # Format the message
    message = format_alert_message(data.head(1))
    
    # Send to Slack
    success = send_slack_alert(webhook_url, message)
    
    if success:
        print("Alert sent successfully to Slack")
    else:
        print("Failed to send alert to Slack")

if __name__ == "__main__":
    main()
