#!/bin/bash

APP_NAME="mywebapp"
DOMAIN="myapp.local"
APP_DIR="/var/www/$APP_NAME"
NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$APP_NAME"
HOSTS_FILE="/etc/hosts"
PORT=80
INDEX_FILE="$APP_DIR/index.html"

error_exit() {
    echo "ERROR: $1"
    exit 1
}

info() {
    echo "$1"
}

if [[ $EUID -ne 0 ]]; then
    error_exit "Run as root or with sudo"
fi

info "Checking application directory..."

if [[ -d "$APP_DIR" ]]; then
    info "Directory exists"
else
    mkdir -p "$APP_DIR" || error_exit "Directory creation failed"
fi

info "Deploying web application..."

if [[ -f "$INDEX_FILE" ]]; then
    info "Web files already exist"
else
    cat <<EOF > "$INDEX_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>Nginx Deployment</title>
</head>
<body>
    <h1>Web App Deployed Successfully</h1>
</body>
</html>
EOF
fi

chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR" || error_exit "Permission setup failed"

info "Configuring Nginx..."

if [[ ! -f "$NGINX_CONF" ]]; then
    cat <<EOF > "$NGINX_CONF"
server {
    listen $PORT;
    server_name $DOMAIN;

    root $APP_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi

if [[ ! -L "$NGINX_LINK" ]]; then
    ln -s "$NGINX_CONF" "$NGINX_LINK"
fi

info "Updating hosts file..."

if ! grep -q "$DOMAIN" "$HOSTS_FILE"; then
    echo "127.0.0.1   $DOMAIN" >> "$HOSTS_FILE"
fi

info "Testing Nginx configuration..."

nginx -t || error_exit "Nginx test failed"

systemctl reload nginx || error_exit "Nginx reload failed"

info "Running smoke test..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN")

if [[ "$HTTP_STATUS" -ne 200 ]]; then
    error_exit "Smoke test failed"
fi

echo "Deployment completed successfully"
echo "Application URL: http://$DOMAIN"

exit 0
