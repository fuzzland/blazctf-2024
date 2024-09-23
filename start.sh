#!/bin/bash

# Check if NAME is provided
if [ -z "$1" ]; then
    echo "Error: NAME is required"
    exit 1
fi

NAME="${1%/}"

YAML_FILE=~/blazctf-2024/$NAME/challenge.yaml

FLAG=$(yq '.metadata.annotations.flag' $NAME/challenge.yaml)
ESCAPED_FLAG=$(printf '%s' "$FLAG" | jq -sRr @json)

# Ensure the base structure exists
yq -i -y '.spec.podTemplate.template.spec.containers[0].name = "challenge"' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env = []' "$YAML_FILE"

# Update or add environment variables
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_ENV", "value": "'"$ENV"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_PUBLIC_HOST", "value": "'"$PUBLIC_HOST"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_ETH_RPC_URL", "value": "'"$ETH_RPC_URL"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_SECRET", "value": "'"$SECRET"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_CHALLENGE_ID", "value": "'"$NAME"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_TEAM_MANAGER", "value": "'"$TEAM_MANAGER"'"}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_FLAG", "value": '$FLAG'}]' "$YAML_FILE"
yq -i -y '.spec.podTemplate.template.spec.containers[0].env += [{"name": "PERSIST_HTTP_PROXY_HOST", "value": "http://127.0.0.1:8080"}]' "$YAML_FILE"

# Run the command
cd ~/blazctf-2024/$NAME
kctf chal start
cd ..
