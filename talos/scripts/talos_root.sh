#!/usr/bin/env bash

if ! command -v kubectl &>/dev/null; then
  echo "kubectl not be found"
  exit 1
fi
if ! command -v fzf &>/dev/null; then
  echo "fzf not be found"
  exit 1
fi

function _kube_list_nodes() {
  # select a node with fzf
  kubectl get nodes |
    fzf --header-lines=1 | awk '{print $1}'
}

function kube-node-admin() {
  NODE=$1
  
  # Debug output to verify the selected node
  echo "Selected node: ${NODE}"
  
  if [[ -z "${NODE}" ]]; then
    echo "Error: No node selected"
    exit 1
  fi

  # Create the full pod spec with node affinity
  read -r -d '' SPEC_JSON <<EOF
{
  "apiVersion": "v1",
  "spec": {
    "affinity": {
      "nodeAffinity": {
        "requiredDuringSchedulingIgnoredDuringExecution": {
          "nodeSelectorTerms": [
            {
              "matchExpressions": [
                {
                  "key": "kubernetes.io/hostname",
                  "operator": "In",
                  "values": [ "${NODE}" ]
                }
              ]
            }
          ]
        }
      }
    },
    "hostNetwork": true,
    "hostPID": true,
    "containers": [{
      "name": "node-admin",
      "image": "debian:latest",
      "stdin": true,
      "stdinOnce": true,
      "tty": true,
      "volumeMounts": [{
        "name": "hostfs",
        "mountPath": "/hostfs"
      }],
      "securityContext": {
        "privileged": true
      }
    }],
    "volumes": [{
      "name": "hostfs",
      "hostPath": {
        "path": "/",
        "type": "Directory"
      }
    }]
  }
}
EOF
  
  # Note: --image is required by kubectl run even when using --overrides (it will be overridden by the JSON spec)
  kubectl run node-admin-${NODE} --namespace kube-system -i -t --rm --restart=Never --image=debian:latest --overrides="${SPEC_JSON}"
}

NODE=$(_kube_list_nodes)

kube-node-admin ${NODE}
