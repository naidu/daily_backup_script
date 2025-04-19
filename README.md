# 🛡️ Daily Backup Script

This script:
- Archives folders listed in `folders.txt` into one compressed `.tar.gz` file.
- Uploads the backup to a remote SFTP server using key-based authentication.
- Keeps only the last N backups (configurable).
- Logs all actions to `/var/log/daily_backup.log`.
- Checks disk usage before and after the backup.
- Sends notifications **on error** via **email** or **Slack** (configurable).

---

## ✅ How to Test the Setup

To make sure everything works (backup, upload, alerts):

```bash
./backup.sh
```
---

## 🔧 Configuration
Edit the top of the `backup.sh` script:

### 🔐 SFTP Settings

```bash
SFTP_USER="your_sftp_user"
SFTP_HOST="your.sftp.host"
SFTP_DIR="/remote/backup/path"
SFTP_KEY="/path/to/private_key"
```

### 📁 Folder List
Update `folders.txt` with **absolute paths** of folders to back up (one per line):

```bash
/etc
/var/www
/home/youruser
```

### ♻️ Retention Policy
Set how many backups to keep on the SFTP:

```bash
KEEP_BACKUPS=5
```

---

## 📧 Email Alerts via Gmail

### Step 1: Install tools

```bash
sudo apt install msmtp msmtp-mta mailutils
```

### Step 2: Configure msmtp
Create `~/.msmtprc`:

```bash
nano ~/.msmtprc
```

Paste in:

```pgsql
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           your.email@gmail.com
user           your.email@gmail.com
passwordeval   gpg --no-tty -q -d ~/.gmail_pass.gpg

account default : gmail
```

Encrypt your Gmail App Password:

```bash
echo "your-app-password" | gpg --symmetric --cipher-algo AES256 -o ~/.gmail_pass.gpg
```

### Step 3: Test email

```bash
echo "This is a test" | mail -s "Test Email" your.email@gmail.com
```

---

## 💬 Slack Alerts

### Step 1: Create a Webhook

* Go to https://api.slack.com/apps

* Create App → **Incoming Webhooks** → Enable → Add Webhook to your desired channel

* Copy the webhook URL

### Step 2: Configure `backup.sh`

```bash
USE_SLACK=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

| 🔔 Only failure notifications will be sent.

---

## 🕒 Setup as Cron Job (Daily at 2 AM)

Edit the crontab:

```bash
crontab -e
```

Add this line:

```pgsql
0 2 * * * /full/path/to/backup.sh
```

Make sure the script is executable:

```bash
chmod +x backup.sh
```

---

## 🧪 Test Error Notification

To simulate an error:

* Temporarily rename a folder listed in folders.txt

* Or rename the SFTP key path

Then run:

```bash
./backup.sh
```

Check if you received the email or Slack alert.

---

## ✅ Optional Improvements

Let us know if you'd like to include:

* ✅ Success notifications

* 🔁 Retry logic

* 🕒 Custom backup time windows

* 🔄 Differential or incremental backups

---
