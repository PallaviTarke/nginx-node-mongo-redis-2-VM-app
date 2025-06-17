FROM google/cloud-sdk:alpine
RUN apk add --no-cache mongodb-tools
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh
ENV CRON_SCHEDULE="0 3 * * *"
CMD echo "$CRON_SCHEDULE /backup.sh" | crontab - && crond -f
