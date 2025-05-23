@@ -1,44 +1,50 @@
#!/bin/bash

clear
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning # Для Google Cloud Shell
echo "Установка зависимостей..."
apt update -y && apt install sudo -y
sudo apt-get update -y --fix-missing
sudo apt-get install wireguard-tools jq wget curl -y --fix-missing

# Установка зависимостей
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "🔧 Установка зависимостей..."
apt update -y && apt install sudo -y 2>/dev/null
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget curl -y --fix-missing

# Сколько конфигов создать
echo -n "Сколько конфигов сгенерировать? (по умолчанию 1): "
read count
# Спросить у пользователя количество конфигов
read -p "Сколько конфигов сгенерировать? (по умолчанию 1): " count
count=${count:-1}

# Cloudflare WARP API и ваша ссылка
api="https://api.cloudflareclient.com/v0i1909051800"
# Ссылка на твой downloader
downloader="https://quad-z.github.io/Warp/downloader.html?filename="

# Вспомогательные функции
# API Cloudflare WARP
api="https://api.cloudflareclient.com/v0i1909051800"
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

clear

for i in $(seq 1 "$count"); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  # Регистрация и активация WARP
  response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
  payload=$(cat <<EOF
{
  "install_id": "",
  "tos": "$(date -u +%FT%T.000Z)",
  "key": "${pub}",
  "fcm_token": "",
  "type": "ios",
  "locale": "en_US"
}
EOF
)

  response=$(ins POST "reg" -d "$payload")
  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')

  peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
  client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
  client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')

  # Генерация конфига в нужном формате
  conf=$(cat <<-EOM
  conf=$(cat <<EOM
[Interface]
PrivateKey = ${priv}
S1 = 0
@@ -61,6 +67,9 @@ Endpoint = 188.114.97.66:3138
EOM
)

  # Кодировка в Base64 и формирование ссылки
  encoded=$(echo -n "$conf" | base64 -w 0)
  echo -e "\n📥 Конф
  conf_base64=$(echo -n "${conf}" | base64 -w 0)
  echo -e "\n📥 Конфиг #$i:"
  echo "${downloader}WARP_${i}.conf&content=${conf_base64}"
done

echo -e "\n✅ Все ссылки готовы."
