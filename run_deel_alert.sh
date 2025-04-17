#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Activate virtual environment
echo "Activating virtual environment..."
source "$SCRIPT_DIR/.venv/bin/activate"

# Check if virtual environment was activated successfully
if [ $? -ne 0 ]; then
  echo "Error: Failed to activate virtual environment. Creating one..."
  python3 -m venv "$SCRIPT_DIR/.venv"
  source "$SCRIPT_DIR/venv/bin/activate"
  
  # Install requirements
  echo "Installing requirements..."
  pip install -r "$SCRIPT_DIR/requirements.txt"
fi

# Prompt for credentials if not provided
if [ -z "$DEEL_INCOMING_WEBHOOK_URL" ]; then
  read -p "Enter your Slack webhook URL: " DEEL_INCOMING_WEBHOOK_URL
  export DEEL_INCOMING_WEBHOOK_URL
fi

if [ -z "$SNOWFLAKE_DEEL_PASSWORD" ]; then
  read -s -p "Enter your Snowflake password: " SNOWFLAKE_DEEL_PASSWORD
  echo
  export SNOWFLAKE_DEEL_PASSWORD
fi

# Run dbt
echo "Running dbt..."
cd "$SCRIPT_DIR/dbt/deel_takehome" && dbt deps &&dbt build --target prod

# Check if dbt run was successful
if [ $? -ne 0 ]; then
  echo "Error: dbt run failed. Exiting."
  exit 1
fi

# Run Slack alert script
echo "Sending Slack alert..."
cd "$SCRIPT_DIR" && python slack_alert.py

echo "Process completed!" 