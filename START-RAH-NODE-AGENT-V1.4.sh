#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT v1.4 STABLE - RAVEN STATUS + TOKEN-PROOF\n'
printf '===========================================================\n'
printf 'Starter Node Agent paa lokalnett, port 18766.\n'
printf 'Eksisterende authority: 4 capabilities, 3 actions, 5 gamle business routes.\n'
printf 'Ny fast read-only route: GET /raven/status.\n'
printf 'Raven-status kan bare kjoere system-inventory via 127.0.0.1:18765.\n'
printf 'Fresh token vises lokalt, men sendes aldri som Bearer over LAN.\n'
printf 'Ingen arbitrary shell, sti, argumenter, generisk process/action eller file API.\n\n'
RAW='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
repair_fixed_file() {
  file="$1"
  [ -f "./$file" ] && return 0
  echo "Mangler $file - henter fast Stable 1.4 runtime fra canonical main..."
  tmp="./$file.rah-download"
  rm -f "$tmp"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RAW/$file" -o "$tmp"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$RAW/$file" -O "$tmp"
  else
    echo 'FEIL: curl eller wget kreves for fast Node-repair.' >&2
    exit 2
  fi
  [ -s "$tmp" ] || { echo "FEIL: tom nedlasting for $file" >&2; rm -f "$tmp"; exit 2; }
  mv -f "$tmp" "./$file"
}
repair_fixed_file 'rah-node-agent-v1.4.py'
repair_fixed_file 'rah-node-agent-v1.4-candidate.py'
[ -f ./rah-node-agent-v1.4.py ] || { echo 'FEIL: rah-node-agent-v1.4.py mangler etter repair.' >&2; exit 1; }
[ -f ./rah-node-agent-v1.4-candidate.py ] || { echo 'FEIL: rah-node-agent-v1.4-candidate.py mangler etter repair.' >&2; exit 1; }
exec python3 ./rah-node-agent-v1.4.py --allow-lan "$@"
