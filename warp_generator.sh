#!/bin/bash

clear

# Зависимости
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "🔧 Установка зависимостей..."
apt update -y && apt install sudo -y 2>/dev/null
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget curl zip -y --fix-missing

# Сколько конфигов?
read -p "Сколько конфигов сгенерировать? (по умолчанию 1): " count
count=${count:-1}

# API и функции
api="https://api.cloudflareclient.com/v0i1909051800"
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

# Папка для конфигов
dir="warp_confs_$(date +%s)"
mkdir "$dir"

for i in $(seq 1 "$count"); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  # Регистрация
  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
  ip_suffix=$((100 + i))
  client_ip="10.10.8.${ip_suffix}"

  # Генерация конфига
  conf=$(cat <<-EOM
[Interface]
Address = ${client_ip}/24
PrivateKey = ${priv}

[Peer]
PublicKey = ${peer_pub}
Endpoint = 203.0.113.2:34567
AllowedIPs = 10.10.8.0/24, 192.168.111.0/24
PersistentKeepalive = 25
EOM
)
  echo "$conf" > "$dir/WARP_$i.conf"
done

# Архив
zip_file="warp_configs_$(date +%s).zip"
zip -j "$zip_file" "$dir"/*.conf >/dev/null
rm -r "$dir"

# Создание base64-контента архива
b64zip=$(base64 -w 0 "$zip_file")
rm "$zip_file"

# Ссылка на скачивание через ваш downloader
echo -e "\n✅ Скачайте ZIP архив по ссылке:"
echo "https://quad-z.github.io/Warp/downloader.html?filename=WARP_Configs.zip&content=$b64zip"
