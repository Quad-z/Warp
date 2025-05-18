#!/bin/bash

set -e

# Проверка и установка зависимостей
for pkg in curl jq wg zip; do
    if ! command -v $pkg &>/dev/null; then
        echo "⏳ Устанавливаем $pkg..."
        sudo apt-get update -y
        sudo apt-get install -y $pkg
    fi
done

API="https://api.cloudflareclient.com/v0i1909051800"

ins() {
    curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "$API/$2" "${@:3}"
}
sec() {
    ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"
}

read -p "Сколько WARP-конфигов сгенерировать? (по умолчанию 25): " COUNT
COUNT=${COUNT:-25}
echo "▶️ Генерируем $COUNT конфигов..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

for i in $(seq 1 $COUNT); do
    echo -ne "  [$i/$COUNT]\r"
    priv=$(wg genkey)
    pub=$(echo "$priv" | wg pubkey)
    resp=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"$pub\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
    if ! echo "$resp" | jq -e '.result.id' >/dev/null 2>&1; then
        echo "❌ Ошибка регистрации $i, пропуск..."
        continue
    fi
    id=$(echo "$resp" | jq -r '.result.id')
    token=$(echo "$resp" | jq -r '.result.token')
    resp=$(sec PATCH "reg/$id" "$token" -d '{"warp_enabled":true}')
    peer_pub=$(echo "$resp" | jq -r '.result.config.peers[0].public_key')
    client_ipv4=$(echo "$resp" | jq -r '.result.config.interface.addresses.v4')
    client_ipv6=$(echo "$resp" | jq -r '.result.config.interface.addresses.v6')
    cat > "$TMPDIR/warp_$i.conf" <<EOF
[Interface]
PrivateKey = $priv
Address = $client_ipv4, $client_ipv6
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $peer_pub
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 188.114.97.66:3138
EOF
done

ZIPNAME="WARP_$(date +%Y%m%d_%H%M%S)_${COUNT}configs.zip"
cd "$TMPDIR"
zip -q "$ZIPNAME" *.conf
cd - >/dev/null

echo "⏫ Загружаем архив на transfer.sh..."
UPLOAD_URL=$(curl --silent --upload-file "$TMPDIR/$ZIPNAME" "https://transfer.sh/$ZIPNAME")
if [[ "$UPLOAD_URL" == https://* ]]; then
    echo -e "\n✅ Всё готово! Ссылка на скачивание архива:"
    echo "$UPLOAD_URL"
    echo "⚠️ Файл будет храниться 14 дней. Скачайте заранее."
else
    echo "❌ Не удалось загрузить архив. Ответ сервера:"
    echo "$UPLOAD_URL"
    exit 1
fi
