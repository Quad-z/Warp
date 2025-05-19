#!/bin/bash

clear

# 📦 Установка зависимостей
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "🔧 Установка зависимостей..."
apt update -y && apt install sudo -y 2>/dev/null
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget curl zip -y --fix-missing

# 📌 Настройки
api="https://api.cloudflareclient.com/v0i1909051800"
base_url="https://quad-z.github.io/Warp/downloader.html"
zip_file="WARP_Configs.zip"

# 🧮 Запрос количества конфигов
read -p "Сколько WARP-конфигов сгенерировать? (по умолчанию 1): " count
count=${count:-1}

# 🧹 Очистка старых файлов
rm -f WARP_*.conf "$zip_file"

# 📡 Запросы
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

# 🔁 Генерация конфигов
for i in $(seq 1 $count); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  echo "🔐 Генерация ключа #$i..."

  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"$pub\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')
  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')

  ip_suffix=$((100 + i))
  client_ip="10.10.8.${ip_suffix}"

  conf=$(cat <<-EOF
[Interface]
Address = ${client_ip}/24
PrivateKey = ${priv}

[Peer]
PublicKey = ${peer_pub}
Endpoint = 203.0.113.2:34567
AllowedIPs = 10.10.8.0/24, 192.168.111.0/24
PersistentKeepalive = 25
EOF
)

  echo "$conf" > "WARP_${i}.conf"
done

# 🗜️ Архивация
echo "📦 Создание ZIP-архива: $zip_file"
zip -j "$zip_file" WARP_*.conf >/dev/null

# 🔐 Кодирование ZIP-файла в base64 (без переносов!)
encoded_zip=$(base64 -w 0 "$zip_file")

# 🔗 Ссылка для скачивания
echo
echo "✅ Ссылка для скачивания архива:"
echo "${base_url}?filename=${zip_file}&content=${encoded_zip}"
echo
