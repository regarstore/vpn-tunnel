#!/bin/bash

# Banner REGAR STORE
echo "REGAR STORE - Tunnel VPN Installer"
echo "Versi: 1.0 | Dikembangkan oleh REGAR STORE"
echo "========================================"

# Cek root
if [ "$EUID" -ne 0 ]; then
  echo "Harap jalankan script sebagai root"
  exit 1
fi

# Variabel global
UUID=$(cat /proc/sys/kernel/random/uuid)
TROJAN_PASS="trojan_password"
DOMAIN=""

# Instalasi dependensi
install_dependencies() {
  apt update -y && apt upgrade -y
  apt install -y curl wget python3-pip ufw
  systemctl stop ufw && ufw disable
}

# Instalasi Xray
install_xray() {
  echo "Instalasi Xray..."
  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
  systemctl enable xray --now
}

# Konfigurasi Xray
configure_xray() {
  cat <<EOF > /usr/local/etc/xray/config.json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificateFile": "/root/cert.crt",
          "keyFile": "/root/priv.key"
        }
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$TROJAN_PASS"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificateFile": "/root/cert.crt",
          "keyFile": "/root/priv.key"
        }
      }
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
  systemctl restart xray
}

# Instalasi OpenSSH
install_ssh() {
  echo "Instalasi OpenSSH..."
  apt install -y openssh-server
  systemctl enable ssh --now
}

# Speed test
speed_test() {
  if ! command -v speedtest-cli &> /dev/null; then
    pip3 install speedtest-cli
  fi
  speedtest-cli --simple
}

# Menu utama
main_menu() {
  while true; do
    clear
    echo "REGAR STORE - Tunnel VPN Installer"
    echo "========================================"
    echo "1. Instal Semua Protokol"
    echo "2. Instal Vmess"
    echo "3. Instal Vless"
    echo "4. Instal Trojan"
    echo "5. Instal SSH"
    echo "6. Speed Test"
    echo "0. Keluar"
    echo "========================================"
    read -p "Pilih opsi [0-6]: " choice

    case $choice in
      1)
        install_xray
        configure_xray
        install_ssh
        echo "Semua protokol telah diinstal!"
        ;;
      2|3|4)
        install_xray
        configure_xray
        echo "Protokol $([ $choice -eq 2 ] && echo "Vmess" || [ $choice -eq 3 ] && echo "Vless" || echo "Trojan") diinstal!"
        ;;
      5)
        install_ssh
        echo "SSH telah diinstal!"
        ;;
      6)
        speed_test
        ;;
      0)
        echo "Keluar..."
        exit 0
        ;;
      *)
        echo "Opsi tidak valid!"
        ;;
    esac
    read -p "Tekan Enter untuk melanjutkan..."
  done
}

# Jalankan script
echo "Masukkan domain Anda:"
read DOMAIN

install_dependencies
main_menu
