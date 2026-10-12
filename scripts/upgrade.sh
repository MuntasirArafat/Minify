#!/bin/bash
## Do not modify this file. You will lose the ability to autoupdate!

VERSION="13"
REPOSITORY_URL="${COOLIFY_REPOSITORY_URL:-https://github.com/MuntasirArafat/Minify.git}"
REPOSITORY_BRANCH="${COOLIFY_REPOSITORY_BRANCH:-main}"
REPOSITORY_DIR="/data/coolify/source/repository"

DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOGFILE="/data/coolify/source/upgrade-${DATE}.log"

if [ ! -d "$REPOSITORY_DIR/.git" ]; then
    git clone --depth 1 --branch "$REPOSITORY_BRANCH" "$REPOSITORY_URL" "$REPOSITORY_DIR"
else
    git -C "$REPOSITORY_DIR" fetch --depth 1 origin "$REPOSITORY_BRANCH"
    git -C "$REPOSITORY_DIR" checkout -B "$REPOSITORY_BRANCH" FETCH_HEAD
fi
cp "$REPOSITORY_DIR/docker-compose.yml" /data/coolify/source/docker-compose.yml
cp "$REPOSITORY_DIR/docker-compose.prod.yml" /data/coolify/source/docker-compose.prod.yml
cp "$REPOSITORY_DIR/.env.production" /data/coolify/source/.env.production

# Merge .env and .env.production. New values will be added to .env
awk -F '=' '!seen[$1]++' /data/coolify/source/.env /data/coolify/source/.env.production  > /data/coolify/source/.env.tmp && mv /data/coolify/source/.env.tmp /data/coolify/source/.env
# Check if PUSHER_APP_ID or PUSHER_APP_KEY or PUSHER_APP_SECRET is empty in /data/coolify/source/.env
if grep -q "PUSHER_APP_ID=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_ID=.*|PUSHER_APP_ID=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

if grep -q "PUSHER_APP_KEY=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_KEY=.*|PUSHER_APP_KEY=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

if grep -q "PUSHER_APP_SECRET=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_SECRET=.*|PUSHER_APP_SECRET=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

# Make sure coolify network exists
# It is created when starting Coolify with docker compose
docker network create --attachable coolify 2>/dev/null
# docker network create --attachable --driver=overlay coolify-overlay 2>/dev/null

echo "If you encounter any issues, please check the log file: $LOGFILE"
if [ -f /data/coolify/source/docker-compose.custom.yml ]; then
    echo "docker-compose.custom.yml detected." >> $LOGFILE
    docker compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml -f /data/coolify/source/docker-compose.custom.yml up -d --build --remove-orphans --force-recreate --wait --wait-timeout 60 >> $LOGFILE 2>&1
else
    docker compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d --build --remove-orphans --force-recreate --wait --wait-timeout 60 >> $LOGFILE 2>&1
fi
