#!/bin/bash

# Установка необходимых зависимостей
install_dependencies() {
    echo "Installing dependencies..."
    apt-get update
    apt-get install -y wget unzip
}

# Установка Xray
install_xray() {
    echo "Downloading Xray..."
    rm -f Xray-linux-64.zip
    wget https://github.com/XTLS/Xray-core/releases/download/v25.2.21/Xray-linux-64.zip
    
    # Создание директорий
    mkdir -p /var/log/xray
    mkdir -p /opt/xray
    
    # Распаковка архива
    unzip -o ./Xray-linux-64.zip -d /opt/xray
    chmod +x /opt/xray/xray

    echo "Configuring Xray service..."
    cat <<EOT > /usr/lib/systemd/system/xray.service
[Unit]
Description=XRay
[Service]
Type=simple
Restart=on-failure
RestartSec=30
WorkingDirectory=/opt/xray
ExecStart=/opt/xray/xray run -c /opt/xray/config.json
[Install]
WantedBy=multi-user.target
EOT

    systemctl daemon-reload
    systemctl enable xray
}

# Генерация ключей и UUID
generate_keys() {
    echo "Generating keys and UUID..."
    cd /opt/xray
    UUID=$(/opt/xray/xray uuid)
    KEYS=$(/opt/xray/xray x25519)
    
    echo "$UUID" > /root/uuid.txt
    echo "$KEYS" > /root/keys.txt
    echo "UUID: $UUID"
    echo "Keys: $KEYS"
}

# Создание базового config.json
create_config() {
    echo "Creating base config.json..."
    cat <<EOT > /opt/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.microsoft.com:443",
                    "serverNames": ["www.microsoft.com"],
                    "privateKey": "",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 0,
                    "shortIds": []
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOT
}

# Настройка config.json
configure_config() {
    echo "Configuring config.json..."
    UUID=$(cat /root/uuid.txt)
    PRIVATE_KEY=$(grep 'Private key:' /root/keys.txt | awk '{print $3}')
    PUBLIC_KEY=$(grep 'Public key:' /root/keys.txt | awk '{print $3}')

    sed -i "s/\"id\": \"\"/\"id\": \"$UUID\"/" /opt/xray/config.json
    sed -i "s/\"privateKey\": \"\"/\"privateKey\": \"$PRIVATE_KEY\"/" /opt/xray/config.json
}

# Генерация клиентской ссылки
generate_client_link() {
    echo "Generating client link..."
    IP=$(hostname -I | awk '{print $1}')
    UUID=$(cat /root/uuid.txt)
    PUBLIC_KEY=$(grep 'Public key:' /root/keys.txt | awk '{print $3}')
    echo "vless://$UUID@$IP:443?security=reality&sni=www.microsoft.com&alpn=h2&fp=chrome&pbk=$PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision&encryption=none#vds"
}

# Основная логика
main() {
    install_dependencies
    install_xray
    create_config
    generate_keys
    configure_config
    systemctl restart xray
    generate_client_link
}

# Запуск
main
