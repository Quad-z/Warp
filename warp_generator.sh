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

# Основной API Cloudflare WARP
api="https://api.cloudflareclient.com/v0i1909051800"
downloader="https://knowerlife.github.io/downloader.html?filename="

ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

clear

for i in $(seq 1 $count); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  # Регистрация ключа
  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  # Активация WARP
  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')

  # Генерация IP в пределах подсети
  ip_suffix=$((100 + i))
  client_ip="10.10.8.${ip_suffix}"

  # Генерация конфига в нужном формате
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

  # Base64 и ссылка на скачивание
  encoded=$(echo -n "$conf" | base64 -w 0)
  echo "📥 Конфиг #$i: ${downloader}WARP_$i.conf&content=${encoded}"
done
