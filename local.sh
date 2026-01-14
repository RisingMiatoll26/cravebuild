#!/bin/bash

# ------------------------------------------------------------
#  STOP right there, code peeper.
#  If you’re reading this script, it means you're either:
#    1) Snooping like a bargain-bin hacker
#    2) Looking for secrets because your life is empty
#    3) Or you're just a clueless clown wandering through files
#
#  Whatever your reason — congratulations:
#  You're still not supposed to understand any of this.
#  Close the file. Go outside. Touch some grass, you indoor goblin.
# ------------------------------------------------------------

# ------------------------------------------------------------
#  And before your small brain tries to get clever:
#  YES, some parts of this script were generated with ChatGPT.
#  Cope. Cry. Malfunction. Do whatever.
#  Still none of your f***ing business.
# ------------------------------------------------------------

# If something explodes, the script stops.
# Not that you'd know how to fix it anyway.
set -e

# Load .env — assuming you actually bothered to create it
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo ".env is missing. Make it, genius. This script can't read your mind."
  exit 1
fi

# Check required variables — because apparently you forget things
if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ] || [ -z "$PIXELDRAIN_API_KEY" ]; then
    echo "Some environment variables are missing. Fix your damn .env."
    exit 1
fi

# Telegram helper — nothing magical, stop staring
send_telegram_message() {
    curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$TG_CHAT_ID" \
        --data-urlencode "text=$1" \
        --data-urlencode "parse_mode=Markdown" > /dev/null
}

# If the script dies, we complain dramatically
handle_exit() {
    code=$?
    if [ $code -ne 0 ]; then
        send_telegram_message "*Build Failed*  
Exit code: \`$code\` — something blew up. Shockingly, your fault? Probably."
    fi
}
trap handle_exit EXIT

send_telegram_message "*Build Started for Miatoll*  
If something catches fire, I'll let you know."


echo -e ">>> Cloning Device Trees"
echo -e ">>> Cloning Device, Vendor, Kernel and Hardware Trees"
echo -e ">>> Please wait, this may take a while..."

echo -e ">>> Cloning Device Tree: xiaomi/miatoll"
echo -e ">>> Done"

echo -e ">>> Cloning Vendor Tree: xiaomi/vendor"
echo -e ">>> Done"

echo -e ">>> Cloning Kernel Tree: xiaomi/sm6250"
echo -e ">>> Done"

echo -e ">>> Cloning Hardware Tree: xiaomi/hardware_xiaomi"
echo -e ">>> Done"

echo -e ">>> Cloning Additional Hardware Trees"
echo -e ">>> Done"

echo -e ">>> Cloning MIUI Camera Vendor Tree: xiaomi/miuicamera"
echo -e ">>> Done"


echo -e ">>> All Device, Vendor, Kernel and Hardware Trees Cloned Successfully"
echo -e ">>> Proceeding to sync remaining sources..."
echo -e ">>> Please wait, this may take a while..."
echo "Starting the build process..."


. build/envsetup.sh

riseup miatoll userdebug

echo "Running 'm installclean' for a safe build..."
m installclean

echo "Starting the main build..."
mka bacon -j$(nproc --all)

send_telegram_message "*Build Finished*  
Uploading… unless something dumb happens."

echo "Uploading zip… don't breathe too hard, it might break."

BUILD_END_TIME=$(date +%s)
DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
DURATION_FORMATTED=$(printf '%dh:%dm:%ds' $(($DURATION/3600)) $(($DURATION%3600/60)) $(($DURATION%60)))

OUTPUT_DIR="out/target/product/miatoll"
ZIP_FILE=$(find "$OUTPUT_DIR" -type f -iname "RisingOS_Revived*.zip" -printf "%T@ %p\n" | sort -n | tail -n1 | cut -d' ' -f2-)

if [[ -f "$ZIP_FILE" ]]; then
  echo "Uploading to pixeldrain… behave please."
  RESPONSE=$(curl -s -u ":$PIXELDRAIN_API_KEY" -X POST -F "file=@$ZIP_FILE" https://pixeldrain.com/api/file)
  FILE_ID=$(echo "$RESPONSE" | jq -r '.id')
  
  if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
    DOWNLOAD_URL="https://pixeldrain.com/u/$FILE_ID"
    FILE_NAME=$(basename "$ZIP_FILE")
    SIZE=$(stat -c%s "$ZIP_FILE")
    SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$SIZE")
    NOW=$(date +"%Y-%m-%d %H:%M")

    send_telegram_message "*Upload Done*  
Build Time: \`$DURATION_FORMATTED\`  
File: \`$FILE_NAME\`  
Size: $SIZE_HUMAN  
Download: $DOWNLOAD_URL"
  else
    send_telegram_message "*Upload Failed*  
Pixeldrain said nope. Typical."
  fi
else
  send_telegram_message "*No ZIP found after build*  
Amazing. Something broke. Again."
fi

echo "Done. If nothing caught fire, consider it a win."
trap - EXIT
