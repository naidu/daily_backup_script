#!/bin/bash

# === Configuration ===
FOLDER_LIST="./folders.txt"
BACKUP_DIR="/tmp/backups"
LOG_FILE="/var/log/daily_backup.log"
SUMMARY_FILE="/tmp/backup_summary.txt"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="full_backup_${DATE}.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"

SFTP_USER="your_sftp_user"
SFTP_HOST="your.sftp.host"
SFTP_DIR="/remote/backup/path"
SFTP_KEY="/path/to/private_key"
KEEP_BACKUPS=5

# === Notification Configuration ===
USE_SLACK=true               # Set to true to use Slack, false to use Email
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"

USE_EMAIL=true               # Set to true to use Email, false to disable
EMAIL_TO="you@example.com"
EMAIL_SUBJECT_ERROR="Backup Failed: $DATE - Missing Items"

# === Progress tracking ===
TOTAL_STEPS=5
CURRENT_STEP=0

# Function to update progress
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo "[$CURRENT_STEP/$TOTAL_STEPS] $1" | tee -a "$LOG_FILE"
}

# === Setup ===
update_progress "Starting backup process"
mkdir -p "$BACKUP_DIR"
echo "=== Backup started at $DATE ===" >> "$LOG_FILE"
echo "Backup Summary - $DATE" > "$SUMMARY_FILE"
ERROR_OCCURRED=0
TOTAL_SIZE_BEFORE=$(df -h / | tail -1)

echo "Disk usage before backup: $TOTAL_SIZE_BEFORE" >> "$SUMMARY_FILE"

# Check if folders.txt exists
update_progress "Checking if folders.txt exists"
if [[ ! -f "$FOLDER_LIST" ]]; then
    echo "Error: $FOLDER_LIST does not exist." >> "$LOG_FILE"
    echo "Error: $FOLDER_LIST does not exist." >> "$SUMMARY_FILE"
    ERROR_OCCURRED=1
    echo "Backup failed. Sending alert..." >> "$LOG_FILE"
    
    if [[ "$USE_SLACK" == "true" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "{"text":"$(cat $SUMMARY_FILE | sed 's/"/\"/g')"}" "$SLACK_WEBHOOK_URL"
    fi

    if [[ "$USE_EMAIL" == "true" ]]; then
        cat "$SUMMARY_FILE" | mail -s "$EMAIL_SUBJECT_ERROR" "$EMAIL_TO"
    fi
    
    echo "=== Backup completed at $(date +"%Y-%m-%d_%H-%M-%S") ===" >> "$LOG_FILE"
    exit 1
fi

# Check if folders.txt is empty
update_progress "Checking if folders.txt is empty"
if [[ ! -s "$FOLDER_LIST" ]]; then
    echo "Error: $FOLDER_LIST is empty. No folders to backup." >> "$LOG_FILE"
    echo "Error: $FOLDER_LIST is empty. No folders to backup." >> "$SUMMARY_FILE"
    ERROR_OCCURRED=1
    echo "Backup failed. Sending alert..." >> "$LOG_FILE"
    
    if [[ "$USE_SLACK" == "true" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "{"text":"$(cat $SUMMARY_FILE | sed 's/"/\"/g')"}" "$SLACK_WEBHOOK_URL"
    fi

    if [[ "$USE_EMAIL" == "true" ]]; then
        cat "$SUMMARY_FILE" | mail -s "$EMAIL_SUBJECT_ERROR" "$EMAIL_TO"
    fi
    
    echo "=== Backup completed at $(date +"%Y-%m-%d_%H-%M-%S") ===" >> "$LOG_FILE"
    exit 1
fi

# Create a temporary file to store valid folders
TEMP_FOLDERS_FILE=$(mktemp)
echo "Valid items to backup:" >> "$LOG_FILE"

# Process folders.txt and create a list of valid folders
update_progress "Processing items from folders.txt"
TOTAL_ITEMS=$(wc -l < "$FOLDER_LIST")
CURRENT_ITEM=0

while read -r ITEM; do
    # Skip empty lines
    if [[ -z "$ITEM" ]]; then
        continue
    fi
    
    # Trim whitespace
    ITEM=$(echo "$ITEM" | xargs)
    CURRENT_ITEM=$((CURRENT_ITEM + 1))
    
    echo "Processing item [$CURRENT_ITEM/$TOTAL_ITEMS]: $ITEM" | tee -a "$LOG_FILE"
    
    if [[ -e "$ITEM" ]]; then
        echo "$ITEM" >> "$TEMP_FOLDERS_FILE"
        echo "  - $ITEM (valid)" >> "$LOG_FILE"
    else
        echo "  - $ITEM (skipped - does not exist)" >> "$LOG_FILE"
        echo "Skipping non-existent item: $ITEM" >> "$SUMMARY_FILE"
    fi
done < "$FOLDER_LIST"

# Check if any valid items were found
if [[ ! -s "$TEMP_FOLDERS_FILE" ]]; then
    echo "Error: No valid items found to backup." >> "$LOG_FILE"
    echo "Error: No valid items found to backup." >> "$SUMMARY_FILE"
    ERROR_OCCURRED=1
    echo "Backup failed. Sending alert..." >> "$LOG_FILE"
    
    if [[ "$USE_SLACK" == "true" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "{"text":"$(cat $SUMMARY_FILE | sed 's/"/\"/g')"}" "$SLACK_WEBHOOK_URL"
    fi

    if [[ "$USE_EMAIL" == "true" ]]; then
        cat "$SUMMARY_FILE" | mail -s "$EMAIL_SUBJECT_ERROR" "$EMAIL_TO"
    fi
    
    rm -f "$TEMP_FOLDERS_FILE"
    echo "=== Backup completed at $(date +"%Y-%m-%d_%H-%M-%S") ===" >> "$LOG_FILE"
    exit 1
fi

# === Create archive ===
update_progress "Creating archive with valid items"
echo "Creating archive $ARCHIVE_PATH with items listed in $FOLDER_LIST" >> "$LOG_FILE"

# Use tar with --files-from to ensure only specified items are included
if tar -czf "$ARCHIVE_PATH" --files-from="$TEMP_FOLDERS_FILE"; then
    echo "Archive created: $ARCHIVE_NAME" >> "$SUMMARY_FILE"
    echo "Archive created successfully with the following items:" >> "$SUMMARY_FILE"
    while read -r ITEM; do
        echo "  - $ITEM" >> "$SUMMARY_FILE"
    done < "$TEMP_FOLDERS_FILE"
else
    echo "Error: Failed to create archive." >> "$LOG_FILE"
    echo "Error: Archive creation failed." >> "$SUMMARY_FILE"
    ERROR_OCCURRED=1
fi

# Clean up temporary file
rm -f "$TEMP_FOLDERS_FILE"

# === Upload to SFTP ===
if [[ $ERROR_OCCURRED -eq 0 ]]; then
    update_progress "Uploading archive to SFTP server"
    echo "Uploading $ARCHIVE_NAME to SFTP..." >> "$LOG_FILE"
    
    # Create a temporary file to store SFTP output
    SFTP_OUTPUT=$(mktemp)
    
    if ! sftp -i "$SFTP_KEY" "$SFTP_USER@$SFTP_HOST" <<EOF > "$SFTP_OUTPUT" 2>&1
cd $SFTP_DIR
put $ARCHIVE_PATH
ls -l $ARCHIVE_NAME
EOF
    then
        echo "Error: SFTP upload failed." >> "$LOG_FILE"
        echo "Error: Failed to upload to SFTP. Details:" >> "$SUMMARY_FILE"
        cat "$SFTP_OUTPUT" >> "$SUMMARY_FILE"
        ERROR_OCCURRED=1
    else
        # Verify the file exists on remote server
        if ! sftp -i "$SFTP_KEY" "$SFTP_USER@$SFTP_HOST" <<EOF > "$SFTP_OUTPUT" 2>&1
cd $SFTP_DIR
ls -l $ARCHIVE_NAME
EOF
        then
            echo "Error: Cannot verify uploaded file on SFTP server." >> "$LOG_FILE"
            echo "Error: Cannot verify uploaded file on SFTP server. Details:" >> "$SUMMARY_FILE"
            cat "$SFTP_OUTPUT" >> "$SUMMARY_FILE"
            ERROR_OCCURRED=1
        else
            if grep -q "$ARCHIVE_NAME" "$SFTP_OUTPUT"; then
                echo "Upload verified successfully. File exists on SFTP server." >> "$SUMMARY_FILE"
                echo "Remote file details:" >> "$SUMMARY_FILE"
                grep "$ARCHIVE_NAME" "$SFTP_OUTPUT" >> "$SUMMARY_FILE"
            else
                echo "Error: Upload appears to have failed - file not found on SFTP server." >> "$LOG_FILE"
                echo "Error: Upload verification failed - file not found on SFTP server." >> "$SUMMARY_FILE"
                ERROR_OCCURRED=1
            fi
        fi
    fi
    
    rm -f "$SFTP_OUTPUT"
fi

# === Cleanup remote backups ===
if [[ $ERROR_OCCURRED -eq 0 ]]; then
    update_progress "Cleaning up old backups on remote server"
    echo "Cleaning up old backups on remote..." >> "$LOG_FILE"
    
    # Create a temporary file to store cleanup output
    CLEANUP_OUTPUT=$(mktemp)
    
    if ! sftp -i "$SFTP_KEY" "$SFTP_USER@$SFTP_HOST" <<EOF > "$CLEANUP_OUTPUT" 2>&1
cd $SFTP_DIR
ls -1 full_backup_*.tar.gz
EOF
    then
        echo "Error: Failed to list remote backups for cleanup." >> "$LOG_FILE"
        echo "Error: Failed to list remote backups for cleanup. Details:" >> "$SUMMARY_FILE"
        cat "$CLEANUP_OUTPUT" >> "$SUMMARY_FILE"
        ERROR_OCCURRED=1
    else
        awk '{print $NF}' "$CLEANUP_OUTPUT" | grep "^full_backup_" | sort -r | tail -n +$(($KEEP_BACKUPS + 1)) > /tmp/old_backups.txt
        
        while read -r OLD_BACKUP; do
            echo "Removing $OLD_BACKUP from SFTP..." >> "$LOG_FILE"
            if ! sftp -i "$SFTP_KEY" "$SFTP_USER@$SFTP_HOST" <<EOF > "$CLEANUP_OUTPUT" 2>&1
cd $SFTP_DIR
rm $OLD_BACKUP
EOF
            then
                echo "Error: Failed to remove old backup $OLD_BACKUP" >> "$LOG_FILE"
                echo "Error: Failed to remove old backup $OLD_BACKUP. Details:" >> "$SUMMARY_FILE"
                cat "$CLEANUP_OUTPUT" >> "$SUMMARY_FILE"
                ERROR_OCCURRED=1
            else
                echo "Successfully removed old backup: $OLD_BACKUP" >> "$SUMMARY_FILE"
            fi
        done < /tmp/old_backups.txt
    fi
    
    rm -f "$CLEANUP_OUTPUT"
fi

rm -f "$ARCHIVE_PATH"

# === Final disk space ===
TOTAL_SIZE_AFTER=$(df -h / | tail -1)
echo "Disk usage after backup: $TOTAL_SIZE_AFTER" >> "$SUMMARY_FILE"

# === Send Notification on Error ===
if [[ $ERROR_OCCURRED -ne 0 ]]; then
    echo "Backup failed. Sending alert..." >> "$LOG_FILE"

    if [[ "$USE_SLACK" == "true" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "{"text":"$(cat $SUMMARY_FILE | sed 's/"/\"/g')"}" "$SLACK_WEBHOOK_URL"
    fi

    if [[ "$USE_EMAIL" == "true" ]]; then
        cat "$SUMMARY_FILE" | mail -s "$EMAIL_SUBJECT_ERROR" "$EMAIL_TO"
    fi
fi

update_progress "Backup process completed"
echo "=== Backup completed at $(date +"%Y-%m-%d_%H-%M-%S") ===" >> "$LOG_FILE"
