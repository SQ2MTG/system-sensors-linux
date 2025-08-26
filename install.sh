#!/bin/bash
set -e

INSTALL_DIR="/opt/system-sensors"
SERVICE_NAME="system-sensors.service"
SCRIPT_PATH="$INSTALL_DIR/system-sensors.sh"

echo "=== Instalator system-sensors ==="

# 1. Aktualizacja systemu
echo "[1/5] Aktualizacja pakietów..."
sudo apt update -y

# 2. Instalacja wymaganych pakietów
echo "[2/5] Instalacja wymaganych pakietów..."
sudo apt install -y lm-sensors smartmontools mosquitto-clients pciutils fancontrol

# (opcjonalne: narzędzia do GPU)
if lspci | grep -qi nvidia; then
    echo "Wykryto NVIDIA GPU – instalacja narzędzi nvidia-smi"
    sudo apt install -y nvidia-utils-535 || true
fi
if lspci | grep -qi amd; then
    echo "Wykryto AMD GPU – (opcjonalnie) rocm-smi"
    sudo apt install -y rocm-smi || true
fi

# 3. Tworzenie katalogu i skryptu
echo "[3/5] Tworzenie skryptu monitorującego..."
sudo mkdir -p "$INSTALL_DIR"

cp temp3.sh $SCRIPT_PATH

sudo chmod +x "$SCRIPT_PATH"

# 4. Tworzenie usługi systemd
echo "[4/5] Tworzenie usługi systemd..."
cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME >/dev/null
[Unit]
Description=System Sensors MQTT Publisher
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=system-sensors
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. Uruchomienie usługi
echo "[5/5] Uruchamianie usługi..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "=== Instalacja zakończona! ==="
echo "Logi: journalctl -u $SERVICE_NAME -f"

sensors
