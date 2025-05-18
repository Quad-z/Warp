#!/bin/bash

mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning # Для Google Cloud Shell, но лучше там не выполнять
echo "[1] Установка зависимостей..."
apt update -y && apt install sudo -y # Для Aeza Terminator, там sudo не установлен по умолчанию
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget -y --fix-missing

echo "[2] Генерация ключей..."
priv="${1:-$(wg genkey)}"
pub="${2:-$(echo "${priv}" | wg pubkey)}"
api="https://api.cloudflareclient.com/v0i1909051800"

ins() {
  curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"
}
sec() {
  ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"
}

echo "[3] Отправка запроса на регистрацию..."
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")

# Проверка, есть ли результат
if ! echo "$response" | jq -e '.result.id' >/dev/null 2>&1; then
  echo "❌ Ошибка: не удалось получить ответ от API. Проверь подключение к интернету."
  exit 1
fi

id=$(echo "$response" | jq -r '.result.id')
token=$(echo "$response" | jq -r '.result.token')

echo "[4] Активация WARP..."
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')

peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')

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

# Сохраняем конфиг в файл
echo "$conf" > warp.conf
echo ""
echo "✅ Файл warp.conf сохранён в текущей директории: $(pwd)/warp.conf"

# Запуск простого сервера Python для скачивания
echo ""
echo "🌍 Локальная ссылка для скачивания (работает пока открыт терминал):"
ip=$(hostname -I | awk '{print $1}')
port=8080
echo "http://$ip:$port/warp.conf"

# Запускаем сервер (если Python установлен)
if command -v python3 >/dev/null; then
  echo "Запуск временного сервера Python на порту $port..."
  python3 -m http.server $port
else
  echo "⚠️ Python не установлен. Установите его, чтобы использовать локальную ссылку."
fi
