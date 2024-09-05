#!/bin/bash

# Check if the processed-config.yaml file exists
if [ ! -f "./egs-installation/egs-installer-config.yaml" ]; then
    echo "Error: egs-installer-config.yaml not found."
    exit 1
fi

# Use \${EXTERNAL_IP} as a literal string
sed -i 's|grafanaDashboardBaseUrl: "http:///d/Oxed_c6Wz"|grafanaDashboardBaseUrl: "http://${EXTERNAL_IP}/d/Oxed_c6Wz"|' ./egs-installation/egs-installer-config.yaml
