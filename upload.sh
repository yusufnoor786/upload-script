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

    curl --progress-bar \
        -T "$FP" \
        -u ":$KEY" \
        https://pixeldrain.com/api/file/

    echo
;;

4)
    echo
    echo "Uploading to Temp.sh..."

    echo
    curl --progress-bar \
        -T "$FP" \
        https://temp.sh

    echo
;;

5)
    echo
    echo "Uploading to Gofile..."

    SERVER=$(curl -s https://api.gofile.io/servers \
        | jq -r '.data.servers[0].name')

    if [[ -z "$SERVER" || "$SERVER" == "null" ]]; then
        echo "Failed to obtain upload server."
        exit 1
    fi

    RESPONSE=$(curl -s \
        --progress-bar \
        -F "file=@${FP}" \
        "https://${SERVER}.gofile.io/uploadFile")

    STATUS=$(echo "$RESPONSE" | jq -r '.status')

    if [[ "$STATUS" != "ok" ]]; then
        echo
        echo "Upload failed!"
        echo "$RESPONSE"
        exit 1
    fi

    LINK=$(echo "$RESPONSE" | jq -r '.data.downloadPage')

    echo
    echo "==========================================="
    echo "Upload Successful!"
    echo "File : $(basename "$FP")"
    echo "Link : $LINK"
    echo "==========================================="
;;

6)
    echo
    echo "Uploading to Oshi.at..."

    echo
    curl --progress-bar \
        -T "$FP" \
        https://oshi.at

    echo
;;

7)
    echo
    echo "Uploading to SourceForge..."

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

    curl -X POST https://vexfile.com/api/upload/handle \
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
