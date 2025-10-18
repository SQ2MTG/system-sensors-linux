# 🧠 System Sensors MQTT Publisher

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Language](https://img.shields.io/badge/shell-bash-lightgrey)
[![CodeFactor](https://www.codefactor.io/repository/github/sq2mtg/system-sensors-linux/badge/main)](https://www.codefactor.io/repository/github/sq2mtg/system-sensors-linux/overview/main)
![MQTT](https://img.shields.io/badge/protocol-MQTT-orange)
![License](https://img.shields.io/badge/license-MIT-yellow)

A lightweight Bash-based monitoring tool that reads system hardware sensors (CPU, GPU, disk, and more) and publishes their readings to an MQTT broker.  
Designed for Linux systems using `lm-sensors`, `smartmontools`, and optional GPU utilities.

---

## 📋 Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [MQTT Topics](#mqtt-topics)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Service Management](#service-management)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## 🧩 Overview

`system-sensors` continuously monitors local hardware metrics and publishes them to an MQTT topic for further integration with monitoring dashboards (e.g. Home Assistant, Grafana, Node-RED).

It detects:
- CPU core and package temperatures
- GPU temperatures (NVIDIA / AMD / other sensors)
- Disk temperatures via S.M.A.R.T.
- Any additional `lm-sensors` readings

All sensor values are colorized in the terminal and periodically sent to an MQTT broker.

---

## ✨ Features
- Real-time terminal display with colored temperature output  
- MQTT publishing per sensor/device  
- Automatic detection of available sensors (CPU, GPU, disks)  
- Works as a systemd service  
- Supports both TCP (`1883`) and WebSocket (`9002/ws`) MQTT connections  

---

## ⚙️ Installation

Run the included installer:

```bash
chmod +x install.sh
sudo ./install.sh
```

This script will:
1. Update system packages  
2. Install dependencies (`lm-sensors`, `mosquitto-clients`, `smartmontools`, etc.)  
3. Create `/opt/system-sensors/` and place the monitoring script there  
4. Set up and enable a `systemd` service (`system-sensors.service`)  
5. Start the service automatically at boot  

After installation, logs are viewable via:
```bash
journalctl -u system-sensors -f
```

---

## 🚀 Usage

To run manually (without systemd):
```bash
bash /opt/system-sensors/system-sensors.sh
```

To stop the background service:
```bash
sudo systemctl stop system-sensors
```

To start it again:
```bash
sudo systemctl start system-sensors
```

---

## 🛰️ MQTT Topics

By default, data is published to:
```
sensors/<hostname>/<category>/<sensor_name>
```

**Examples:**
```
sensors/server01/cpu/Core0
sensors/server01/gpu/nvidia
sensors/server01/disk/nvme0n1
```

You can adjust the broker or topic settings at the top of the script:
```bash
MQTT_HOST="10.10.0.4"
MQTT_PORT="1883"
MQTT_TOPIC="sensors"
```

---

## 📦 Dependencies

Installed automatically via the installer:
- `lm-sensors`
- `smartmontools`
- `mosquitto-clients`
- `pciutils`
- `fancontrol`

Optional (detected automatically):
- `nvidia-utils` (for NVIDIA GPUs)
- `rocm-smi` (for AMD GPUs)

---

## 🧰 Configuration

You can edit `/opt/system-sensors/system-sensors.sh` to customize:
- MQTT host and port  
- Topic root name  
- Update interval (`sleep 2` at the bottom of the loop)  
- Sensor inclusion/exclusion logic  

---

## 🔧 Service Management

Enable on boot:
```bash
sudo systemctl enable system-sensors
```

Disable:
```bash
sudo systemctl disable system-sensors
```

View logs:
```bash
journalctl -u system-sensors -f
```

---

## 🩺 Troubleshooting

- **No sensors detected:**  
  Run `sudo sensors-detect` and reboot.
- **MQTT not receiving data:**  
  Check broker IP/port and topic in the script.  
  Test with:
  ```bash
  mosquitto_sub -h <host> -t "sensors/#" -v
  ```
- **Permission errors:**  
  Ensure `system-sensors.sh` is executable:
  ```bash
  sudo chmod +x /opt/system-sensors/system-sensors.sh
  ```

---

## 📜 License

This project is released under the **MIT License**.  
Use freely, modify, and share with attribution.


## 💡 Autor

**Błażej SQ2MTG**  