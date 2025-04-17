#!/bin/bash
set -e

# Sostituisci con il tuo ID progetto
PROJECT_ID=playground-s-11-0a723cfb
REGION=us-central1
ZONE=us-central1-a
SUBNET=custom-subnet

# Legge l'HTML e lo formatta per YAML
HTML=$(cat html/index.html  | awk '{print "        value: \""$0"\""}')

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
$HTML
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

# Crea il nuovo instance template
gcloud deployment-manager deployments create $TEMPLATE_NAME --config=new-template.yaml

# Ottiene il selfLink del nuovo template
TEMPLATE=$(gcloud compute instance-templates list --filter="name=$TEMPLATE_NAME" --format="value(selfLink)" | head -n 1)

# Aggiorna il MIG
gcloud compute instance-groups managed set-instance-template nginx-mig --template=$TEMPLATE --zone=$ZONE
gcloud compute instance-groups managed rolling-action replace nginx-mig --zone=$ZONE

