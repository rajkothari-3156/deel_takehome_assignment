#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ALERT_SCRIPT="$SCRIPT_DIR/run_deel_alert.sh"
TEMP_CRONTAB=$(mktemp)
crontab -l > "$TEMP_CRONTAB" 2>/dev/null || echo "" > "$TEMP_CRONTAB"

# Check if the cron job already exists
if grep -q "$ALERT_SCRIPT" "$TEMP_CRONTAB"; then
  echo "Cron job for $ALERT_SCRIPT already exists."
else
  
  echo "0 8 * * * $ALERT_SCRIPT >> $SCRIPT_DIR/cron.log 2>&1" >> "$TEMP_CRONTAB"
  
  # Install the new crontab
  crontab "$TEMP_CRONTAB"
  
  echo "Cron job added to run $ALERT_SCRIPT daily at 8:00 AM."
  echo "Logs will be written to $SCRIPT_DIR/cron.log"
fi

# Clean up
rm "$TEMP_CRONTAB"

echo "Cron setup complete!" 