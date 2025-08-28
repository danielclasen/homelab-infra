#!/usr/bin/env bash

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Define the path to the talosconfig file relative to the script's directory
TALOSCONFIG_PATH="$SCRIPT_DIR/../clusterconfig/talosconfig"

# Define the subnet to filter nodes by
SUBNET="192.168.91.0/24"

# Define the path to the talos configuration file
TALOSCONFIG_YAML="$SCRIPT_DIR/../talconfig.yaml"

# The subnet prefix, e.g., "192.168.91."
SUBNET_PREFIX=$(echo "$SUBNET" | cut -d'.' -f1-3)
SUBNET_PREFIX+="."

# Extract control plane node IPs in the specified subnet using yq
NODE_IPS=($(SUBNET_PREFIX_VAR="$SUBNET_PREFIX" yq -r '
  .nodes[] |
  select(.controlPlane == true) |
  .networkInterfaces[].addresses[] |
  select(. | test("^" + env(SUBNET_PREFIX_VAR))) |
  split("/")[0]' "$TALOSCONFIG_YAML"))

# Check if any IPs were found
if [ ${#NODE_IPS[@]} -eq 0 ]; then
  echo "No control plane nodes found in subnet $SUBNET"
  exit 1
fi

for ip in "${NODE_IPS[@]}"; do
  talosctl --talosconfig "$TALOSCONFIG_PATH" --nodes "$ip" etcd status
done
