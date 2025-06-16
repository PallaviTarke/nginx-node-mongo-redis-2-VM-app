#!/bin/bash
mkdir -p /backup
docker exec mongo sh -c 'mongodump --archive' > /backup/mongo-$(date +%F_%H-%M).archive