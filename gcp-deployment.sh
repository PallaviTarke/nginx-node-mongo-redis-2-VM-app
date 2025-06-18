#!/bin/bash

# Configuration
PROJECT_ID="project-pallavi-tarke"
INSTANCE_NAME="app-vm"
MACHINE_TYPE="e2-standard-8"
ZONE="asia-south1-c"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
STARTUP_SCRIPT="startup.sh"
SERVICE_ACCOUNT="app-service-account@project-pallavi-tarke.iam.gserviceaccount.com"
REPO_URL="https://github.com/PallaviTarke/nginx-node-mongo-redis-2-VM-app.git"
BUCKET_NAME="mongobackupbucket"
INSTANCE_GROUP="app-group"
INSTANCE_TEMPLATE="app-template"
HEALTH_CHECK="app-health-check"
BACKEND_SERVICE="app-backend"
URL_MAP="app-lb"
HTTP_PROXY="app-http-proxy"
FORWARDING_RULE="app-http-rule"
FIREWALL_RULE_HTTP="allow-http-https"
FIREWALL_RULE_MONITORING="allow-monitoring"

# Cleanup
echo "Cleaning up existing resources..."
gcloud compute forwarding-rules delete ${FORWARDING_RULE} --global --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute target-http-proxies delete ${HTTP_PROXY} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute url-maps delete ${URL_MAP} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute backend-services delete ${BACKEND_SERVICE} --global --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute health-checks delete ${HEALTH_CHECK} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute instance-groups managed delete ${INSTANCE_GROUP} --zone=${ZONE} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute instance-templates delete ${INSTANCE_TEMPLATE} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute firewall-rules delete ${FIREWALL_RULE_HTTP} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute firewall-rules delete ${FIREWALL_RULE_MONITORING} --quiet --project=${PROJECT_ID} 2>/dev/null
gcloud compute instances delete $(gcloud compute instances list --project=${PROJECT_ID} --filter="name~^app" --format="value(name)") --zone=${ZONE} --quiet --project=${PROJECT_ID} 2>/dev/null
gsutil rm -r gs://${BUCKET_NAME} 2>/dev/null

# Project config
gcloud config set project ${PROJECT_ID}

# Startup script
cat << EOF > ${STARTUP_SCRIPT}
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git
systemctl start docker
systemctl enable docker
usermod -aG docker pallavi
git clone ${REPO_URL} /app
chown -R pallavi:pallavi /app
chmod -R u+w /app
cd /app
export GCP_PROJECT_ID=${PROJECT_ID}
export GCP_BUCKET=${BUCKET_NAME}
su - pallavi -c "docker-compose up -d"
EOF

# Firewalls
echo "Creating firewall rules..."
gcloud compute firewall-rules create ${FIREWALL_RULE_HTTP} \
  --project=${PROJECT_ID} \
  --allow=tcp:80,tcp:443 \
  --target-tags=http-server,https-server

gcloud compute firewall-rules create ${FIREWALL_RULE_MONITORING} \
  --project=${PROJECT_ID} \
  --allow=tcp:3001,tcp:9090 \
  --target-tags=http-server

# Instance template
echo "Creating instance template..."
gcloud compute instance-templates create ${INSTANCE_TEMPLATE} \
  --project=${PROJECT_ID} \
  --machine-type=${MACHINE_TYPE} \
  --image-family=${IMAGE_FAMILY} \
  --image-project=${IMAGE_PROJECT} \
  --scopes=cloud-platform \
  --service-account=${SERVICE_ACCOUNT} \
  --metadata-from-file=startup-script=${STARTUP_SCRIPT} \
  --tags=http-server,https-server

# Managed instance group
echo "Creating managed instance group..."
gcloud compute instance-groups managed create ${INSTANCE_GROUP} \
  --project=${PROJECT_ID} \
  --zone=${ZONE} \
  --base-instance-name=app \
  --size=2 \
  --template=${INSTANCE_TEMPLATE}

# Set named port for backend service
gcloud compute instance-groups managed set-named-ports ${INSTANCE_GROUP} \
  --zone=${ZONE} \
  --named-ports=http:80

# Autoscaling
echo "Configuring autoscaling..."
gcloud compute instance-groups managed set-autoscaling ${INSTANCE_GROUP} \
  --project=${PROJECT_ID} \
  --zone=${ZONE} \
  --max-num-replicas=4 \
  --min-num-replicas=2 \
  --target-cpu-utilization=0.6

# Storage bucket
echo "Creating storage bucket..."
gsutil mb -p ${PROJECT_ID} -l asia-south1 gs://${BUCKET_NAME}

# Load balancer
echo "Creating load balancer..."
gcloud compute health-checks create http ${HEALTH_CHECK} \
  --project=${PROJECT_ID} \
  --port=80 \
  --request-path=/health

gcloud compute backend-services create ${BACKEND_SERVICE} \
  --project=${PROJECT_ID} \
  --protocol=HTTP \
  --health-checks=${HEALTH_CHECK} \
  --global

gcloud compute backend-services add-backend ${BACKEND_SERVICE} \
  --project=${PROJECT_ID} \
  --instance-group=${INSTANCE_GROUP} \
  --instance-group-zone=${ZONE} \
  --global

gcloud compute url-maps create ${URL_MAP} \
  --project=${PROJECT_ID} \
  --default-service=${BACKEND_SERVICE}

gcloud compute target-http-proxies create ${HTTP_PROXY} \
  --project=${PROJECT_ID} \
  --url-map=${URL_MAP}

gcloud compute forwarding-rules create ${FORWARDING_RULE} \
  --project=${PROJECT_ID} \
  --global \
  --target-http-proxy=${HTTP_PROXY} \
  --ports=80

# Wait and verify
echo "Verifying deployment..."
sleep 120
gcloud compute instances list --project=${PROJECT_ID}
LB_IP=$(gcloud compute forwarding-rules describe ${FORWARDING_RULE} --global --project=${PROJECT_ID} --format='value(IPAddress)')
echo "Load Balancer IP: ${LB_IP}"
curl -I http://${LB_IP} 2>/dev/null || echo "Health check failed, check VM logs"

# High availability test
echo "Testing high availability..."
INSTANCE_TO_DELETE=$(gcloud compute instances list --project=${PROJECT_ID} --filter="name~^app" --limit=1 --format="value(name)")
if [[ -n "${INSTANCE_TO_DELETE}" ]]; then
  gcloud compute instances delete ${INSTANCE_TO_DELETE} --zone=${ZONE} --quiet --project=${PROJECT_ID}
fi
sleep 60
gcloud compute instance-groups managed list-instances ${INSTANCE_GROUP} --zone=${ZONE} --project=${PROJECT_ID}
curl -I http://${LB_IP} 2>/dev/null || echo "Post-failure check failed"

echo "Deployment complete. Monitor at http://${LB_IP}, Prometheus at http://${LB_IP}:9090, Grafana at http://${LB_IP}:3001"

