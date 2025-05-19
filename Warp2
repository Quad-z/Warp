#!/bin/bash

clear

# Установка зависимостей
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "🔧 Установка зависимостей..."
apt update -y && apt install sudo -y 2>/dev/null
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget curl -y --fix-missing

# Сколько конфигов создать
echo -n "Сколько конфигов сгенерировать? (по умолчанию 1): "
read count
count=${count:-1}

# Cloudflare WARP API и ваша ссылка
api="https://api.cloudflareclient.com/v0i1909051800"
downloader="https://quad-z.github.io/Warp/downloader.html?filename="

# Вспомогательные функции
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

clear

for i in $(seq 1 "$count"); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  # Регистрация и активация WARP
  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
  client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
  client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')

  # Генерация конфига в нужном формате
  conf=$(cat <<-EOM
[Interface]
PrivateKey = ${priv}
S1 = 0
S2 = 0
Jc = 120
Jmin = 23
Jmax = 911
H1 = 1
H2 = 2
H3 = 3
H4 = 4
MTU = 1280
Address = ${client_ipv4}, ${client_ipv6}
DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001

[Peer]
PublicKey = ${peer_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 188.114.97.66:3138
EOM
)

  # Кодировка в Base64 и формирование ссылки
  encoded=$(echo -n "$conf" | base64 -w 0)
  echo -e "\n📥 Конф
