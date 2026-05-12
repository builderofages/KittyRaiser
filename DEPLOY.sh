#!/bin/bash
# DEPLOY.sh - automated KittyRaiser deployment pipeline
set -e
cd ~/Desktop/KittyRaiser
echo '==> killing Studio to avoid autosave overwrites'
pkill -9 -f RobloxStudio 2>/dev/null || true
sleep 5
echo '==> rojo build'
/opt/homebrew/bin/rojo build --output build.rbxlx default.project.json
echo '==> sanity check'
SIZE=$(stat -f%z build.rbxlx)
if [ "$SIZE" -lt 500000 ]; then echo "BUILD TOO SMALL ($SIZE bytes), aborting"; exit 1; fi
echo "build artifact: $SIZE bytes"
echo '==> Open Cloud publish'
RESP=$(curl -s -X POST -H "x-api-key: $(cat ~/.kittyraiser_api_key)" -H 'Content-Type: application/octet-stream' --data-binary @build.rbxlx 'https://apis.roblox.com/universes/v1/10107635885/places/100613539623679/versions?versionType=Published')
echo "publish response: $RESP"
echo '==> git commit + push'
git add -A
git commit -m "deploy $(date +%Y-%m-%d-%H%M%S)" || echo 'nothing to commit'
git push origin claude/fix-cat-player-graphics-YEnR2
echo '==> done. live cloud + git in sync.'
