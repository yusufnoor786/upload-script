#!/usr/bin/env bash

set -e

echo
echo "==================== Upload Manager ===================="
echo "[1] Github Release (gh auth login required)"
echo "[2] DevUploads (API Key)"
echo "[3] PixelDrain (API Key)"
echo "[4] Temp.sh"
echo "[5] Gofile"
echo "[6] Oshi.at"
echo "[7] SourceForge"
echo "[8] VexFiles (API Key + File URL)"
echo "========================================================"
echo

read -rp "Please enter your number: " UP

if [[ "$UP" == "8" ]]; then
    read -rp "Please enter uploaded file URL: " URL
else
    read -erp "Please enter file path: " FP

    if [[ ! -f "$FP" ]]; then
        echo "Error: File not found!"
        exit 1
    fi
fi

read_secret() {
    printf "%s" "$1"
    KEY=""

    while IFS= read -r -s -n1 c; do
        [[ $c == $'\n' || $c == $'\0' ]] && printf "\n" && break

        if [[ $c == $'\177' ]]; then
            KEY="${KEY%?}"
            printf "\b \b"
        else
            KEY+="$c"
            printf "*"
        fi
    done
}

case "$UP" in

1)
    read -rp "Please enter GitHub repo (owner/repo): " GH

    TAG=$(basename "$FP")
    TAG="${TAG%.*}"

    echo
    echo "Creating GitHub Release..."

    gh release create "$TAG" \
        --generate-notes \
        --repo "$GH"

    gh release upload \
        --clobber \
        "$TAG" \
        "$FP" \
        --repo "$GH"

    echo
    echo "Upload completed!"
;;

2)
    read_secret "Please enter DevUploads API Key: "

    echo
    echo "Uploading to DevUploads..."

    bash <(curl -fsSL https://devuploads.com/upload.sh) \
        -f "$FP" \
        -k "$KEY"
;;

3)
    read_secret "Please enter PixelDrain API Key: "

    echo
    echo "Uploading to PixelDrain..."

    curl \
        --progress-bar \
        --show-error \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        -T "$FP" \
        -u ":$KEY" \
        https://pixeldrain.com/api/file/

    echo
;;

4)
    echo
    echo "Uploading to Temp.sh..."
    echo

    curl \
        --progress-bar \
        --show-error \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        -T "$FP" \
        https://temp.sh

    echo
;;

5)
    echo
    echo "Uploading to Gofile..."
    echo

    # Gofile automatic upload endpoint.
    # Gofile selects the appropriate upload region automatically.
    GOFILE_ENDPOINT="https://upload.gofile.io/uploadfile"

    TMP_RESPONSE=$(mktemp)

    cleanup() {
        rm -f "$TMP_RESPONSE"
    }

    trap cleanup EXIT

    echo "==========================================="
    echo "Uploading: $(basename "$FP")"
    echo "Size     : $(du -h "$FP" | cut -f1)"
    echo "Endpoint : $GOFILE_ENDPOINT"
    echo "==========================================="
    echo

    START_TIME=$(date +%s)

    if ! curl \
        --progress-bar \
        --show-error \
        --fail \
        --location \
        --connect-timeout 15 \
        --retry 3 \
        --retry-delay 2 \
        --retry-connrefused \
        --write-out "\n\nUploaded: %{size_upload} bytes\nAverage Speed: %{speed_upload} bytes/sec\nTotal Time: %{time_total} sec\n" \
        -o "$TMP_RESPONSE" \
        -F "file=@${FP}" \
        "$GOFILE_ENDPOINT"
    then
        echo
        echo "==========================================="
        echo "           GOFILE UPLOAD FAILED"
        echo "==========================================="
        echo
        cat "$TMP_RESPONSE" 2>/dev/null || true
        exit 1
    fi

    echo

    RESPONSE=$(cat "$TMP_RESPONSE")

    STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')

    if [[ "$STATUS" != "ok" ]]; then
        echo "==========================================="
        echo "           GOFILE UPLOAD FAILED"
        echo "==========================================="
        echo
        echo "$RESPONSE"
        exit 1
    fi

    LINK=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')

    if [[ -z "$LINK" || "$LINK" == "null" ]]; then
        echo "==========================================="
        echo "Upload completed but no download URL found."
        echo "==========================================="
        echo
        echo "$RESPONSE"
        exit 1
    fi

    SIZE=$(stat -c%s "$FP")
    SIZE_HUMAN=$(du -h "$FP" | cut -f1)

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    if (( ELAPSED > 0 )); then
        SPEED=$((SIZE / ELAPSED))
    else
        SPEED=0
    fi

    echo
    echo "==========================================="
    echo "        GOFILE UPLOAD SUCCESSFUL"
    echo "==========================================="
    echo "File Name : $(basename "$FP")"
    echo "File Size : ${SIZE_HUMAN} (${SIZE} bytes)"
    echo "Time      : ${ELAPSED} seconds"
    echo "Speed     : ${SPEED} bytes/sec"
    echo "Link      : ${LINK}"
    echo "==========================================="
;;

6)
    echo
    echo "Uploading to Oshi.at..."
    echo

    curl \
        --progress-bar \
        --show-error \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        -T "$FP" \
        https://oshi.at

    echo
;;

7)
    echo
    echo "Uploading to SourceForge..."
    echo

    read -rp "Username: " USER

    echo
    echo "Path after /home/frs/project/"
    read -rp "> " UPL

    scp "$FP" \
        "${USER}@frs.sourceforge.net:/home/frs/project/${UPL}"

    echo
    echo "Upload completed!"
;;

8)
    read_secret "Please enter VexFiles API Key: "

    echo
    echo "Uploading to VexFiles..."

    curl \
        --show-error \
        --fail \
        --retry 3 \
        --retry-delay 2 \
        -X POST \
        https://vexfile.com/api/upload/handle \
        -H "Content-Type: application/json" \
        -d "{
            \"token\":\"$KEY\",
            \"url\":\"$URL\"
        }"

    echo
;;

*)
    echo "Invalid option."
    exit 1
;;

esac
