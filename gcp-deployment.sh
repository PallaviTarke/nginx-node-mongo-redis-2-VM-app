#!/bin/bash

# Configuration
PROJECT_ID=${GCP_PROJECT_ID}
INSTANCE_NAME="app-vm"
MACHINE_TYPE="e2-standard-8"
ZONE="us-central1-a"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
STARTUP_SCRIPT="startup.sh"
SERVICE_ACCOUNT="app-service-account@$PROJECT_ID.iam.gserviceaccount.com"
REPO_URL="YOUR_REPOSITORY_URL"
BUCKET_NAME=" nodejsmongoredis-storagebucket"

# Create startup script
cat << EOF > startup.sh
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git
systemctl start docker
systemctl enable docker
git clone $REPO_URL /app
cd /app
export GCP_PROJECT_ID=$PROJECT_ID
export GCP_BUCKET=$BUCKET_NAME
docker-compose up -d
EOF

# Set up GCP project
gcloud config set project $PROJECT_ID

# Create firewall rules
gcloud compute firewall-rules create allow-http-https \
  --project=$PROJECT_ID \
  --allow=tcp:80,tcp:443 \
  --target-tags=http-server,https-server

# Create instance template
gcloud compute instance-templates create app-template \
  --project=$PROJECT_ID \
  --machine-type=$MACHINE_TYPE \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --scopes=cloud-platform \
  --service-account=$SERVICE_ACCOUNT \
  --metadata-from-file=startup-script=startup.sh \
  --tags=http-server,https-server

# Create managed instance group with minimum 2 instances
gcloud compute instance-groups managed create app-group \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --base-instance-name=app \
  --size=2 \
  --template=app-template

# Configure autoscaling
gcloud compute instance-groups managed set-autoscaling app-group \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --max-num-replicas=4 \
  --min-num-replicas=2 \
  --target-cpu-utilization=0.6

# Create HTTP load balancer
gcloud compute health-checks create http app-health-check \
  --project=$PROJECT_ID \
  --port=80 \
  --request-path=/health

gcloud compute backend-services create app-backend \
  --project=$PROJECT_ID \
  --protocol=HTTP \
  --health-checks=app-health-check \
  --global

gcloud compute backend-services add-backend app-backend \
  --project=$PROJECT_ID \
  --instance-group=app-group \
  --instance-group-zone=$ZONE \
  --global

gcloud compute url-maps create app-lb \
  --project=$PROJECT_ID \
  --default-service=app-backend

gcloud compute target-http-proxies create app-http-proxy \
  --project=$PROJECT_ID \
  --url-map=app-lb

gcloud compute forwarding-rules create app-http-rule \
  --project=$PROJECT_ID \
  --global \
  --target-http-proxy=app-http-proxy \
  --ports=80
