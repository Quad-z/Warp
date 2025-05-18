#!/bin/bash

# Проверка зависимостей
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v wg &> /dev/null || ! command -v zip &> /dev/null; then
    echo "❌ Устанавливаем зависимости..."
    mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
    sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget zip -y --fix-missing
fi

# Настройка API
api="https://api.cloudflareclient.com/v0i1909051800"

ins() {
    curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"
}

sec() {
    ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"
}

# Запрос количества конфигов
read -p "🔄 Сколько конфигов WARP сгенерировать? (по умолчанию 25): " COUNT
COUNT=${COUNT:-25}
echo "🛠 Генерация $COUNT конфигураций..."

# Временное хранилище
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Основной цикл генерации
for i in $(seq 1 $COUNT); do
    echo -ne "⚙️ Прогресс: $i/$COUNT"\\r
    
    priv=$(wg genkey)
    pub=$(echo "$priv" | wg pubkey)
    
    response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"$pub\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")
    
    if ! echo "$response" | jq -e '.result.id' >/dev/null; then
        echo "❌ Ошибка при создании конфига $i"
        continue
    fi
    
    id=$(jq -r '.result.id' <<< "$response")
    token=$(jq -r '.result.token' <<< "$response")
    response=$(sec PATCH "reg/$id" "$token" -d '{"warp_enabled":true}')
    
    # Формирование конфига
    conf="[Interface]
PrivateKey = $priv
Address = $(jq -r '.result.config.interface.addresses.v4' <<< "$response"), $(jq -r '.result.config.interface.addresses.v6' <<< "$response")
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = $(jq -r '.result.config.peers[0].public_key' <<< "$response")
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 188.114.97.66:3138"
    
    echo "$conf" > "$TMPDIR/warp_$i.conf"
done

# Архивирование
ZIP_NAME="WARP_${COUNT}configs_$(date +%d%m%Y).zip"
cd "$TMPDIR" || exit
zip -q -9 "../$ZIP_NAME" *.conf
cd - >/dev/null || exit

# Получение ссылки
UPLOAD_URL=$(curl --upload-file "./$ZIP_NAME" "https://transfer.sh/$ZIP_NAME" 2>/dev/null)

# Результат
echo -e "\n✅ Готово! Ссылка для скачивания:"
echo "🔗 $UPLOAD_URL"
echo "⚠️ Файл будет доступен 14 дней. Рекомендуем скачать его сразу!"
