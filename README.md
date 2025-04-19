# Daily Backup Script

This script:
- Archives folders listed in `folders.txt` into one compressed `.tar.gz` file.
- Uploads the backup to a remote SFTP server using key-based authentication.
- Keeps only the last N backups (configurable via `KEEP_BACKUPS`).
- Logs all actions to `/var/log/daily_backup.log`.
- Sends an email notification with a summary only if the backup fails.

## Requirements
- `tar`, `sftp`, `mail`, and `df` commands available.
- `mailutils` or similar email system installed and configured (e.g., `msmtp` with Gmail).
- Private key set correctly in `SFTP_KEY`.

## Setup
1. Fill in configuration values at the top of `backup.sh`.
2. List directories to back up in `folders.txt`.
3. Schedule the script using `cron`.

## Example Cron Entry
```
0 2 * * * /path/to/backup.sh
```

This will run the script daily at 2:00 AM.
