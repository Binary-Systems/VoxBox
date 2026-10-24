#!/bin/bash
# Build a Kubernetes Secret from user-data.yaml + network-data.yaml for Harvester.
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
NS=${NAMESPACE:-default}
NAME=${SECRET_NAME:-voxbox-cloudinit}
kubectl -n "$NS" create secret generic "$NAME" \
  --from-file=userdata="$DIR/user-data.yaml" \
  --from-file=networkdata="$DIR/network-data.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Applied secret $NS/$NAME (keys: userdata, networkdata)"
