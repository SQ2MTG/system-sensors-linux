#!/bin/bash
set -e

INSTALL_DIR="/opt/system-sensors"
SERVICE_NAME="system-sensors.service"
SCRIPT_PATH="$INSTALL_DIR/system-sensors.sh"

echo "=== Instalator system-sensors ==="

# --- Interaktywne pytanie o połączenie MQTT ---
echo "Wybierz sposób połączenia z brokerem MQTT:"
echo "1) LAN (domyślny: 10.10.0.4)"
echo "2) VPN (ustaw IP na 10.10.10.4)"
read -p "Twój wybór [1/2]: " CONNECTION_CHOICE

if [[ "$CONNECTION_CHOICE" == "2" ]]; then
    MQTT_HOST="10.10.10.4"
else
    MQTT_HOST="10.10.0.4"
fi

echo "Ustawiono adres MQTT: $MQTT_HOST"

# 1. Aktualizacja systemu
echo "[1/5] Aktualizacja pakietów..."
sudo apt update -y

# 2. Instalacja wymaganych pakietów
echo "[2/5] Instalacja wymaganych pakietów..."
sudo apt install -y lm-sensors smartmontools mosquitto-clients pciutils

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

cat <<EOF | sudo tee "$SCRIPT_PATH" >/dev/null
#!/bin/bash

# Konfiguracja MQTT
MQTT_HOST="$MQTT_HOST"
MQTT_PORT="1883"
MQTT_TOPIC="sensors"

HOSTNAME=\$(hostname)

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

get_color() {
    local temp=\$1
    if (( temp >= 80 )); then
        echo -e "\${RED}\${temp}°C\${NC}"
    elif (( temp >= 60 )); then
        echo -e "\${YELLOW}\${temp}°C\${NC}"
    else
        echo -e "\${GREEN}\${temp}°C\${NC}"
    fi
}

publish_mqtt() {
    local key=\$1
    local value=\$2
    mosquitto_pub -h "\$MQTT_HOST" -p "\$MQTT_PORT" -t "\$MQTT_TOPIC/\$HOSTNAME/\$key" -m "\$value" >/dev/null 2>&1
}

while true; do
    clear
    echo -e "=== \${YELLOW}Monitor temperatur (\$HOSTNAME)\${NC} ==="

    # CPU
    echo -e "\nCPU:"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        # Raspberry Pi
        temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        echo -e "SoC: $(get_color "$temp")"
        publish_mqtt "cpu/soc" "$temp"
    else
        # inne systemy
        sensors | grep -E "Core|Package" | while read -r line; do
            temp=$(echo "$line" | grep -oP '\+?\K[0-9]+(?=\.?[0-9]*°C)' | head -n1)
            if [[ -n "$temp" ]]; then
                color_temp=$(get_color "$temp")
                name=$(echo "$line" | awk '{print $1}' | tr -d ':')
                echo "$line" | sed -E "s/([0-9]+\.?[0-9]*°C)/$color_temp/"
                publish_mqtt "cpu/$name" "$temp"
            else
                echo "$line"
            fi
        done
    fi

    # GPU
    echo -e "\nGPU:"
    gpu_found=false

    if command -v rocm-smi &>/dev/null; then
        temp=\$(rocm-smi --showtemp | grep -oP '[0-9]+(?=\.0\s*C)' | head -n1)
        if [ -n "\$temp" ]; then
            echo -e "AMD GPU: \$(get_color "\$temp")"
            publish_mqtt "gpu/amd" "\$temp"
            gpu_found=true
        fi
    fi

    if command -v nvidia-smi &>/dev/null; then
        temp=\$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
        if [[ "\$temp" =~ ^[0-9]+$ ]]; then
            echo -e "NVIDIA GPU: \$(get_color "\$temp")"
            publish_mqtt "gpu/nvidia" "\$temp"
            gpu_found=true
        fi
    fi

    if [ "\$gpu_found" = false ]; then
        temp=\$(sensors | grep -iE 'edge|junction|mem|gpu' | grep -oP '[0-9]+(?=\.?[0-9]*°C)' | head -n1)
        if [[ "\$temp" =~ ^[0-9]+$ ]]; then
            echo -e "Inne GPU: \$(get_color "\$temp")"
            publish_mqtt "gpu/other" "\$temp"
        else
            echo "Brak danych GPU"
        fi
    fi

    # Dyski
    echo -e "\nDyski:"
    for disk in /dev/nvme* /dev/sd[a-z]; do
        [ -b "\$disk" ] || continue
        temp=\$(sudo smartctl -A "\$disk" 2>/dev/null | awk '/Temperature_Celsius|Temperature:/ {print \$10; exit}')
        if [[ "\$temp" =~ ^[0-9]+$ ]]; then
            echo -e "\$disk: \$(get_color "\$temp")"
            publish_mqtt "disk/\$(basename "\$disk")" "\$temp"
        fi
    done

    sleep 2
done
EOF

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
