#!/bin/bash

# Use a backup directory inside your project folder
BACKUP_DIR="/home/pallavi/nodejs-mongo-redis-gcp/backup/data"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%F_%H-%M")
mongodump --host mongo --port 27017 --archive="$BACKUP_DIR/mongo-$TIMESTAMP.archive"

echo "Backup completed at $TIMESTAMP" >> /var/log/backup.log

