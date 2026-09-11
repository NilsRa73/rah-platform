#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT v1.3 STABLE - TOKEN-PROOF + FIXED ALLOWLIST\n'
printf '=============================================================\n'
printf 'Starter Node Agent paa lokalnett, port 18766.\n'
printf 'Fast authority: 4 capabilities, 3 actions, 5 business routes.\n'
printf 'Fresh token vises lokalt, men sendes aldri som Bearer over LAN.\n'
printf 'Beskyttede requests bruker source-bound single-use nonce + HMAC-SHA256 proof.\n'
printf 'Muterende actions beholder ephemeral CC approval, Node-local bekreftelse, requester-source/context og proof/challenge.\n'
printf 'Ingen shell, generic process/action, filer, installasjon eller native fjernstyring.\n'
printf 'Eksempel: --capability storage --capability remote-desktop\n\n'
if [ ! -f ./rah-node-agent-v1.3.py ]; then
  echo 'FEIL: rah-node-agent-v1.3.py mangler. Kjoer UPDATE-RAH-RAVEN.ps1 paa Windows-hovedinstallasjonen eller oppdater CC-pakken.' >&2
  exit 1
fi
exec python3 ./rah-node-agent-v1.3.py --allow-lan "$@"
