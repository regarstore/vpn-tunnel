#!/bin/bash

# REGAR STORE VPN MANAGER LIFETIME
# Creator: REGAR STORE - 082274942599
# Version: 2.0 (Multi-Port Support)

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config files
XRAY_CONFIG="/etc/xray/config.json"
ACCOUNT_FILE="/etc/regarstore/accounts.txt"
IPTABLES_LOG="/var/log/regar_iptables.log"
CERTS_DIR="/etc/xray/certs"

# Ensure required packages are installed
function install_dependencies() {
    echo -e "${YELLOW}[*] Installing dependencies...${NC}"
    apt-get update > /dev/null 2>&1
    apt-get install -y jq iptables-persistent fail2ban speedtest-cli uuid-runtime openssl nginx > /dev/null 2>&1
    systemctl enable fail2ban nginx > /dev/null 2>&1
    systemctl start fail2ban > /dev/null 2>&1
    mkdir -p /etc/regarstore $CERTS_DIR
    touch $ACCOUNT_FILE
    chmod 600 $ACCOUNT_FILE
    
    # Install latest speedtest-cli
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash > /dev/null 2>&1
    apt-get install -y speedtest > /dev/null 2>&1
}

# Install XRay core
function install_xray() {
    if [[ ! -f /usr/local/bin/xray ]]; then
        echo -e "${YELLOW}[*] Installing XRay Core...${NC}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
        systemctl enable xray > /dev/null 2>&1
        systemctl start xray > /dev/null 2>&1
    fi
}

# Generate TLS certificates
function generate_certificates() {
    if [[ ! -f $CERTS_DIR/xray.crt ]]; then
        echo -e "${YELLOW}[*] Generating TLS certificates...${NC}"
        openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
            -keyout $CERTS_DIR/xray.key -out $CERTS_DIR/xray.crt \
            -subj "/CN=regarstore.com" > /dev/null 2>&1
    fi
}

# Setup Nginx for port 80 and 443 fallback
function setup_nginx() {
    echo -e "${YELLOW}[*] Configuring Nginx...${NC}"
    cat <<EOF > /etc/nginx/sites-available/regarstore
server {
    listen 80;
    listen [::]:80;
    server_name _;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    ssl_certificate $CERTS_DIR/xray.crt;
    ssl_certificate_key $CERTS_DIR/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/regarstore /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx > /dev/null 2>&1
}

# Initialize XRay configuration with multi-port support
function init_config() {
    if [[ ! -f $XRAY_CONFIG ]]; then
        echo -e "${YELLOW}[*] Creating initial XRay configuration...${NC}"
        cat <<EOF > $XRAY_CONFIG
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          {"dest": 80},
          {"dest": 8080},
          {"dest": 8443}
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERTS_DIR/xray.crt",
              "keyFile": "$CERTS_DIR/xray.key"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "vless-443"
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "vmess-80"
    },
    {
      "port": 8080,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERTS_DIR/xray.crt",
              "keyFile": "$CERTS_DIR/xray.key"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "trojan-8080"
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERTS_DIR/xray.crt",
              "keyFile": "$CERTS_DIR/xray.key"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "vless-ws-8443"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
        systemctl restart xray > /dev/null 2>&1
    fi
}

# Add user account with multi-port support
function create_account() {
    echo -e "${BLUE}Select protocol:${NC}"
    echo "1. VMESS"
    echo "2. VLESS"
    echo "3. TROJAN"
    echo "4. SSH"
    echo -n "Enter choice (1-4): "
    read protocol_choice

    case $protocol_choice in
        1) protocol="vmess" ;;
        2) protocol="vless" ;;
        3) protocol="trojan" ;;
        4) protocol="ssh" ;;
        *) echo -e "${RED}Invalid choice!${NC}"; return ;;
    esac

    echo -n "Enter username: "
    read username
    echo -n "Set IP limit: "
    read iplimit
    echo -n "Set expiration (days): "
    read expdays
    echo -n "Set bandwidth limit (MB): "
    read bwlimit

    uuid=$(uuidgen)
    password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo '')
    exp_date=$(date -d "+$expdays days" +%Y-%m-%d)
    
    # For SSH, generate random port
    if [[ $protocol == "ssh" ]]; then
        port=$(( ( RANDOM % 10000 ) + 10000 ))
    else
        port="multi"
    fi

    case $protocol in
        vmess)
            jq --arg uuid "$uuid" --arg email "$username" \
            '.inbounds[] | select(.tag == "vmess-80") | 
            .settings.clients += [{"id":$uuid,"email":$email}]' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            ;;
        vless)
            jq --arg uuid "$uuid" --arg email "$username" \
            '.inbounds[] | select(.tag == "vless-443" or .tag == "vless-ws-8443") | 
            .settings.clients += [{"id":$uuid,"email":$email}]' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            ;;
        trojan)
            jq --arg uuid "$uuid" --arg email "$username" \
            '.inbounds[] | select(.tag == "trojan-8080") | 
            .settings.clients += [{"password":$uuid,"email":$email}]' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            ;;
        ssh)
            useradd -M -s /bin/false $username
            echo "$username:$password" | chpasswd
            # Open port in firewall
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            ;;
    esac

    # Save account info
    echo "$protocol:$username:$uuid:$password:$iplimit:$exp_date:$bwlimit:$port" >> $ACCOUNT_FILE
    systemctl restart xray > /dev/null 2>&1

    # Apply IP limit for SSH
    if [[ $protocol == "ssh" ]]; then
        apply_iplimit "$username" "$iplimit" "$port"
    fi

    echo -e "${GREEN}Account created successfully!${NC}"
    echo -e "${YELLOW}Protocol: $protocol"
    echo "Username: $username"
    echo "Password: $password"
    [[ $protocol != "trojan" ]] && echo "UUID: $uuid" || echo "Password: $uuid"
    [[ $protocol == "ssh" ]] && echo "Port: $port" || echo "Ports: 80,443,8080,8443"
    echo "IP Limit: $iplimit"
    echo "Exp Date: $exp_date"
    echo "Bandwidth: ${bwlimit}MB${NC}"
}

# Apply IP limit
function apply_iplimit() {
    username=$1
    iplimit=$2
    port=$3

    # Flush existing rules
    iptables -D INPUT -p tcp --dport $port -m connlimit --connlimit-above $iplimit -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --dport $port -m connlimit --connlimit-above $iplimit -j DROP
    
    # Logging
    echo "$(date) - IPLIMIT set for $username: $iplimit connections on port $port" >> $IPTABLES_LOG
}

# Delete account
function delete_account() {
    echo -n "Enter username to delete: "
    read username
    
    if grep -q "^.*:$username:" $ACCOUNT_FILE; then
        # Get account details
        protocol=$(grep "^.*:$username:" $ACCOUNT_FILE | cut -d: -f1)
        uuid=$(grep "^.*:$username:" $ACCOUNT_FILE | cut -d: -f3)
        port=$(grep "^.*:$username:" $ACCOUNT_FILE | cut -d: -f8)
        
        if [[ $protocol != "ssh" ]]; then
            if [[ $protocol == "vmess" ]]; then
                jq --arg uuid "$uuid" \
                '.inbounds[] | select(.tag == "vmess-80") | 
                .settings.clients = (.settings.clients | map(select(.id != $uuid)))' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            elif [[ $protocol == "vless" ]]; then
                jq --arg uuid "$uuid" \
                '.inbounds[] | select(.tag == "vless-443" or .tag == "vless-ws-8443") | 
                .settings.clients = (.settings.clients | map(select(.id != $uuid)))' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            elif [[ $protocol == "trojan" ]]; then
                jq --arg uuid "$uuid" \
                '.inbounds[] | select(.tag == "trojan-8080") | 
                .settings.clients = (.settings.clients | map(select(.password != $uuid)))' $XRAY_CONFIG > tmp.$$.json && mv tmp.$$.json $XRAY_CONFIG
            fi
        else
            userdel -r $username 2>/dev/null
            # Remove port from firewall
            iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
            # Remove IP limit rule
            iptables -D INPUT -p tcp --dport $port -m connlimit --connlimit-above $iplimit -j DROP 2>/dev/null
        fi
        
        # Remove from account file
        sed -i "/^.*:$username:/d" $ACCOUNT_FILE
        systemctl restart xray > /dev/null 2>&1
        
        echo -e "${GREEN}Account $username deleted!${NC}"
    else
        echo -e "${RED}Account not found!${NC}"
    fi
}

# Run speedtest
function run_speedtest() {
    echo -e "${YELLOW}[*] Running speed test...${NC}"
    speedtest --accept-license --simple
}

# Show all accounts
function show_accounts() {
    if [[ -s $ACCOUNT_FILE ]]; then
        echo -e "${YELLOW}\nList of Accounts:${NC}"
        echo "--------------------------------------------------------------------------------------------------"
        printf "%-8s | %-15s | %-36s | %-12s | %-8s | %-10s | %-10s | %-5s\n" \
            "Proto" "Username" "UUID/Password" "IP Limit" "Exp Date" "BW Limit" "BW Used" "Port"
        echo "--------------------------------------------------------------------------------------------------"
        
        while IFS=: read -r protocol username uuid password iplimit exp_date bwlimit port; do
            printf "%-8s | %-15s | %-36s | %-12s | %-10s | %-10s | %-10s | %-5s\n" \
                "$protocol" "$username" "$uuid" "$iplimit" "$exp_date" "${bwlimit}MB" "0MB" "$port"
        done < $ACCOUNT_FILE
        
        echo "--------------------------------------------------------------------------------------------------"
        echo -e "${YELLOW}Note: Port 'multi' means supports 80,443,8080,8443${NC}"
    else
        echo -e "${RED}No accounts found!${NC}"
    fi
}

# Main menu
function main_menu() {
    while true; do
        echo -e "\n${BLUE}REGAR STORE VPN MANAGER${NC}"
        echo -e "${YELLOW}Created by REGAR STORE - 082274942599${NC}"
        echo "------------------------------------"
        echo "1. Create VPN Account"
        echo "2. Delete VPN Account"
        echo "3. Run Speed Test"
        echo "4. Show All Accounts"
        echo "5. Exit"
        echo -n "Enter choice (1-5): "
        read choice

        case $choice in
            1) create_account ;;
            2) delete_account ;;
            3) run_speedtest ;;
            4) show_accounts ;;
            5) exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Initialization
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

install_dependencies
install_xray
generate_certificates
setup_nginx
init_config
main_menu
