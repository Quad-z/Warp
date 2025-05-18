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

# Генерация конфигов
success_count=0
for i in $(seq 1 $COUNT); do
    echo -ne "  Прогресс: $i/$COUNT [Успешно: $success_count]\r"
    
    # Генерация ключей
    priv=$(wg genkey)
    pub=$(echo "$priv" | wg pubkey)
    
    # Регистрация устройства
    if ! resp=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"$pub\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}"); then
        echo "❌ Ошибка сети при регистрации $i"
        continue
    fi
    
    # Проверка ответа
    if ! echo "$resp" | jq -e '.result.id' >/dev/null 2>&1; then
        echo "❌ Неверный ответ API для $i"
        continue
    fi
    
    # Активация WARP
    id=$(echo "$resp" | jq -r '.result.id')
    token=$(echo "$resp" | jq -r '.result.token')
    resp=$(sec PATCH "reg/$id" "$token" -d '{"warp_enabled":true}')
    
    # Создание конфига
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
    
    ((success_count++))
done

echo -e "\n✅ Успешно сгенерировано $success_count/$COUNT конфигов"

# Архивирование
ZIPNAME="WARP_$(date +%Y%m%d_%H%M%S)_${success_count}configs.zip"
cd "$TMPDIR"
zip -q "$ZIPNAME" *.conf
cd - >/dev/null

# Проверка архива
if [ ! -f "$TMPDIR/$ZIPNAME" ]; then
    echo "❌ Файл архива не найден"
    exit 1
fi

# Двойная загрузка на разные сервисы
upload_success=0
echo "⏫ Пытаемся загрузить на transfer.sh..."
if UPLOAD_URL=$(curl --progress-bar --upload-file "$TMPDIR/$ZIPNAME" "https://transfer.sh/$ZIPNAME"); then
    if [[ "$UPLOAD_URL" == https://* ]]; then
        echo -e "\n🔗 Основная ссылка (transfer.sh):"
        echo "$UPLOAD_URL"
        upload_success=1
    fi
fi

if [ $upload_success -eq 0 ]; then
    echo "⏫ Альтернативная загрузка на file.io..."
    if RESPONSE=$(curl -s -F "file=@$TMPDIR/$ZIPNAME" https://file.io/?expires=14d); then
        if UPLOAD_URL=$(echo "$RESPONSE" | jq -r '.link'); then
            echo -e "\n🔗 Резервная ссылка (file.io):"
            echo "$UPLOAD_URL"
            upload_success=1
        fi
    fi
fi

# Финал
if [ $upload_success -eq 1 ]; then
    echo -e "\n⚠️ Ссылка действительна 14 дней. Рекомендуем:"
    echo "1. Скопировать ссылку выше"
    echo "2. Проверить скачивание в браузере"
    echo "3. Сохранить архив локально"
else
    echo "❌ Все способы загрузки не сработали"
    echo "Архив временно сохранён здесь:"
    echo "$TMPDIR/$ZIPNAME"
fi
