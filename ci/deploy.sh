#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: ci/deploy.sh PRODUCTION|STAGING"
    exit 1
fi

BASEPATH="$(dirname "$0")"
IMAGE_NAME="congame:$GITHUB_SHA"
TARGET_HOST="deepploy@$DEPLOY_HOST"

case "$1" in
    PRODUCTION)
        CONTAINER_NAME="congame-production"
        CONTAINER_PORT="8000"
        ENVIRONMENT_PATH="$BASEPATH/production.env"
        RUN_PATH="/var/run/congame/production"
    ;;
    STAGING)
        CONTAINER_NAME="congame-staging"
        CONTAINER_PORT="9000"
        ENVIRONMENT_PATH="$BASEPATH/staging.env"
        RUN_PATH="/var/run/congame/staging"
    ;;
    *)
        echo "error: expected $1 to be either PRODUCTION or STAGING"
        exit 1
    ;;
esac

log() {
    printf "[%s] %s" "$(date)" "$@"
}

log "Loading the key..."
echo "$DEPLOY_KEY" > /tmp/deploy-key
chmod 0600 /tmp/deploy-key

log "Copying the image..."
docker save "$IMAGE_NAME" | \
    ssh -o "StrictHostKeyChecking off" -i /tmp/deploy-key "$TARGET_HOST" docker load

log "Restarting the container..."
ssh -o "StrictHostKeyChecking off" -i /tmp/deploy-key "$TARGET_HOST" <<EOF
  mkdir -p "$RUN_PATH"
EOF
scp -o "StrictHostKeyChecking off" -i /tmp/deploy-key "$ENVIRONMENT_PATH" "$TARGET_HOST:$RUN_PATH/env"
ssh -o "StrictHostKeyChecking off" -i /tmp/deploy-key "$TARGET_HOST" <<EOF
  docker stop "$CONTAINER_NAME" || true
  docker rm "$CONTAINER_NAME" || true
  docker run \
    --name "$CONTAINER_NAME" \
    --env-file "$RUN_PATH/env" \
    -v "$RUN_PATH":"$RUN_PATH" \
    -p "$CONTAINER_PORT":"$CONTAINER_PORT" \
    "$IMAGE_NAME"
EOF