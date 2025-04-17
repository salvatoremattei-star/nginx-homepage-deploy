#!/bin/bash
set -e

# Impostazioni progetto
PROJECT_ID=playground-s-11-0a723cfb
REGION=us-central1
ZONE=us-central1-a
SUBNET=custom-subnet

# Script di avvio (startup-script) da inserire nel template
STARTUP_SCRIPT=$(cat <<'EOT'
        value: |
          #!/bin/bash
          apt-get update
          apt-get install -y nginx
          cat <<EOF_HTML > /var/www/html/index.html
          <!DOCTYPE html>
          <html>
          <head><title>Homepage</title></head>
          <body>
            <h1>Benvenuto sulla homepage aggiornata!</h1>
          </body>
          </html>
EOF_HTML
          systemctl enable nginx
          systemctl restart nginx
EOT
)

# Nome univoco per il nuovo template
TEMPLATE_NAME=homepage-template-$(date +%s)

# Creazione file YAML del nuovo instance template
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
$STARTUP_SCRIPT
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

# Deploy del nuovo template
gcloud deployment-manager deployments create $TEMPLATE_NAME --config=new-template.yaml

# Recupero del selfLink del template appena creato
TEMPLATE=$(gcloud compute instance-templates list \
  --filter="name=$TEMPLATE_NAME" \
  --format="value(selfLink)" | head -n 1)

# Aggiorna il MIG
gcloud compute instance-groups managed set-instance-template nginx-mig \
  --template=$TEMPLATE \
  --zone=$ZONE

# Rolling update delle VM
gcloud compute instance-groups managed rolling-action replace nginx-mig \
  --zone=$ZONE

