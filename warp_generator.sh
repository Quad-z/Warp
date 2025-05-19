#!/bin/bash

clear

# Установка зависимостей
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "🔧 Установка зависимостей..."
apt update -y && apt install sudo -y 2>/dev/null
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget curl -y --fix-missing

# Спрашиваем количество конфигов
echo -n "Сколько конфигов сгенерировать? (по умолчанию 1): "
read count
count=${count:-1}

# API Cloudflare WARP
api="https://api.cloudflareclient.com/v0i1909051800"

# Ваша ссылка на downloader.html (замени на свою!)
downloader="https://quad-z.github.io/Warp/downloader.html?filename="

# Функции для запросов
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

clear

for i in $(seq 1 "$count"); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  # Регистрация ключа
  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  # Активация WARP
  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')

  # Генерация IP
  ip_suffix=$((100 + i))
  client_ip="10.10.8.${ip_suffix}"

  # Конфигурация
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

  # Base64 и ссылка
  encoded=$(echo -n "$conf" | base64 -w 0)
  echo -e "\n📥 Ссылка для скачивания конфигурации #$i:"
  echo "${downloader}WARP_${i}.conf&content=${encoded}"
done
