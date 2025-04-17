#!/bin/bash
set -e

# Configurazione progetto
PROJECT_ID=playground-s-11-0a723cfb
REGION=us-central1
ZONE=us-central1-a
SUBNET=custom-subnet

# Carica il file HTML dal repository e lo inserisce nella startup-script
STARTUP_SCRIPT=$(cat <<EOT
        value: |
          #!/bin/bash
          apt-get update
          apt-get install -y nginx
          cat <<EOF > /var/www/html/index.html
$(cat html/index.html)
EOF
          systemctl enable nginx
          systemctl restart nginx
EOT
)

# Crea un nome univoco per l'instance template
TEMPLATE_NAME=homepage-template-$(date +%s)

# Crea il file YAML del template
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

# Crea il nuovo template
gcloud deployment-manager deployments create $TEMPLATE_NAME --config=new-template.yaml

# Ottiene il selfLink
TEMPLATE=$(gcloud compute instance-templates list \
  --filter="name=$TEMPLATE_NAME" \
  --format="value(selfLink)" | head -n 1)

# Aggiorna il MIG
gcloud compute instance-groups managed set-instance-template nginx-mig \
  --template=$TEMPLATE \
  --zone=$ZONE

# Rolling update
gcloud compute instance-groups managed rolling-action replace nginx-mig \
  --zone=$ZONE

