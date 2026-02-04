#!/bin/bash

set -e

# -------------------------
# Auto Detect Network Info
# -------------------------

INTERFACE=$(ip route | grep default | awk '{print $5}')
LOCAL_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
ROUTER_MAC=$(ip neigh show "$GATEWAY_IP" | awk '{print $5}')

if [[ -z "$ROUTER_MAC" ]]; then
  ping -c 1 "$GATEWAY_IP" > /dev/null 2>&1
  ROUTER_MAC=$(ip neigh show "$GATEWAY_IP" | awk '{print $5}')
fi

# -------------------------
# User Inputs
# -------------------------

read -p "Kharj IP: " KHARJ_IP
read -p "Tunnel Port: " TUNNEL_PORT
read -p "Config Ports (comma separated): " PORTS
SECRET_KEY="e4f1a7c9b2d84a0f9c3e7b6d1a5f9021"
read -p "Log level [info]: " LOG_LEVEL

LOG_LEVEL=${LOG_LEVEL:-info}

# -------------------------
# Paths & Names
# -------------------------

BASE_DIR="/opt/paqet"
BIN_PATH="/usr/local/bin/paqet"
SERVICE_NAME="paqet-client-${KHARJ_IP//./-}"
CONFIG_FILE="$BASE_DIR/client-${KHARJ_IP}.yaml"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

mkdir -p "$BASE_DIR"

# -------------------------
# Generate YAML
# -------------------------

cat <<EOF > "$CONFIG_FILE"
role: "client"

log:
  level: "$LOG_LEVEL"

forward:
EOF

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
for PORT in "${PORT_ARRAY[@]}"; do
  PORT=$(echo "$PORT" | xargs)
  cat <<EOF >> "$CONFIG_FILE"
  - listen: "0.0.0.0:$PORT"
    target: "$KHARJ_IP:$PORT"
    protocol: "tcp"
EOF
done

cat <<EOF >> "$CONFIG_FILE"

network:
  interface: "$INTERFACE"
  ipv4:
    addr: "$LOCAL_IP:0"
    router_mac: "$ROUTER_MAC"

server:
  addr: "$KHARJ_IP:$TUNNEL_PORT"

transport:
  protocol: "kcp"
  kcp:
    block: "aes"
    key: "$SECRET_KEY"
EOF

# -------------------------
# Create systemd service
# -------------------------

cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Paqet Client ($KHARJ_IP)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN_PATH run -c $CONFIG_FILE
Restart=always
RestartSec=5
LimitNOFILE=1048576

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# -------------------------
# Enable & Start Service
# -------------------------

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# -------------------------
# Output
# -------------------------

echo ""
echo "✅ Config ساخته شد: $CONFIG_FILE"
echo "✅ Service ساخته شد: $SERVICE_NAME"
echo ""
echo "📌 دستورات مفید:"
echo "systemctl status $SERVICE_NAME"
echo "journalctl -u $SERVICE_NAME -f"
echo "systemctl restart $SERVICE_NAME"
