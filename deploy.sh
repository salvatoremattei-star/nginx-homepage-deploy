#!/bin/bash
set -e

PROJECT_ID=playground-s-11-0a723cfb
REGION=us-central1
ZONE=us-central1-a
SUBNET=custom-subnet
TEMPLATE_NAME=homepage-template-$(date +%s)

cat <<EOF > new-template.yaml
resources:
- name: $TEMPLATE_NAME
  type: compute.v1.instanceTemplate
  properties:
    properties:
      machineType: e2-standard-2
      tags:
        items: [allow-health-check]
      metadata:
        items:
        - key: startup-script
          value: |
            #!/bin/bash
            apt-get update
            apt-get install -y nginx
            echo '$(cat html/index.html)' > /var/www/html/index.html
            systemctl enable nginx
            systemctl restart nginx
      networkInterfaces:
      - subnetwork: projects/$PROJECT_ID/regions/$REGION/subnetworks/$SUBNET
        accessConfigs:
        - name: External NAT
          type: ONE_TO_ONE_NAT
      disks:
      - deviceName: boot
        type: PERSISTENT
        boot: true
        autoDelete: true
        initializeParams:
          sourceImage: projects/debian-cloud/global/images/family/debian-12
      serviceAccounts:
      - email: default
        scopes: [https://www.googleapis.com/auth/cloud-platform]
EOF

gcloud deployment-manager deployments create $TEMPLATE_NAME --config=new-template.yaml
TEMPLATE=$(gcloud compute instance-templates list --filter="name=$TEMPLATE_NAME" --format="value(selfLink)" | head -n 1)

gcloud compute instance-groups managed set-instance-template nginx-mig \
  --template=$TEMPLATE \
  --zone=$ZONE

gcloud compute instance-groups managed rolling-action replace nginx-mig \
  --zone=$ZONE

