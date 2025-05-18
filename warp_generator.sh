#!/bin/bash

clear
echo -n "Сколько конфигов сгенерировать? (по умолчанию 1): "
read count
count=${count:-1}

mkdir -p warp_confs
for i in $(seq 1 $count); do
  priv=$(wg genkey)
  pub=$(echo "$priv" | wg pubkey)

  response=$(curl -s -X POST "https://api.cloudflareclient.com/v0a769/reg" \
    -H 'Content-Type: application/json' \
    -d "{\"key\":\"$pub\",\"install_id\":\"\",\"fcm_token\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"type\":\"ios\",\"locale\":\"en_US\"}")

  id=$(echo "$response" | jq -r '.result.id')
  token=$(echo "$response" | jq -r '.result.token')

  patch=$(curl -s -X PATCH "https://api.cloudflareclient.com/v0a769/reg/$id" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
    -d '{"warp_enabled":true}')

  peer_pub=$(echo "$patch" | jq -r '.result.config.peers[0].public_key')
  client_ipv4=$(echo "$patch" | jq -r '.result.config.interface.addresses.v4')
  client_ipv6=$(echo "$patch" | jq -r '.result.config.interface.addresses.v6')

  cat <<EOF > "warp_confs/WARP_$i.conf"
[Interface]
PrivateKey = $priv
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
Address = $client_ipv4, $client_ipv6
DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001

[Peer]
PublicKey = $peer_pub
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 188.114.97.66:3138
EOF
done

zip -r warp_confs.zip warp_confs > /dev/null

echo -e "\n✅ Конфиги сохранены в архив: warp_confs.zip"

# Найдём свободный порт от 8000 до 8100
for port in {8000..8100}; do
  if ! lsof -i :$port >/dev/null; then
    free_port=$port
    break
  fi
done

if [ -z "$free_port" ]; then
  echo "❌ Не удалось найти свободный порт для веб-сервера."
  exit 1
fi

# Запуск локального веб-сервера
echo -e "\n🌐 Локальная ссылка для скачивания архива:"
ip=$(hostname -I | awk '{print $1}')
echo "👉 http://${ip}:${free_port}/warp_confs.zip"

echo -e "\nНажмите Ctrl+C чтобы остановить сервер."

python3 -m http.server "$free_port"
