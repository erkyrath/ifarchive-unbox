#!/bin/sh

CONF_FILE=/etc/nginx/conf.d/default.conf
OPTIONS_FILE=$DATA_DIR/options.json

# Get values from options.json
DOMAIN=$(jq -r '.domain? // ""' $OPTIONS_FILE)
KEYS_SIZE=$(jq -r '.nginx?.cache?.keys_size? // 50' $OPTIONS_FILE)
MAX_SIZE=$(jq -r '.nginx?.cache?.max_size? // 1000' $OPTIONS_FILE)
SUBDOMAINS=$(jq -r '.subdomains? // false' $OPTIONS_FILE)

# Top server
if [ -n "$DOMAIN" ]; then
    SERVER_NAME="server_name $DOMAIN;"
fi;
cat > $CONF_FILE <<EOF
server {
    listen 80;
    listen [::]:80;
    $SERVER_NAME

    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host \$host;
    }
}
EOF

if [ -n "$DOMAIN" ] && [ "$SUBDOMAINS" = "true" ]; then

# Subdomain server
cat >> $CONF_FILE <<EOF

proxy_cache_path ${DATA_DIR}/nginx-cache keys_zone=cache:${KEYS_SIZE}m levels=1:2 max_size=${MAX_SIZE}m;

server {
    listen 80;
    listen [::]:80;
    server_name *.${DOMAIN};

    proxy_cache cache;

    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host \$host;
        add_header X-Cache \$upstream_cache_status;
    }
}
EOF

fi;

# Log the contructed config file
cat $CONF_FILE

nginx -g 'daemon off;'