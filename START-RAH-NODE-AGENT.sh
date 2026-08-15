#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT - FIXED ACTION AND APP ALLOWLIST\n'
printf '================================================\n'
printf 'Starter /health og /actions paa lokalnett, port 18766.\n'
printf '/storage finnes bare med --capability storage.\n'
printf '/launch/rustdesk annonseres bare med --capability remote-desktop og lokal RustDesk.\n'
printf 'RustDesk-launch tar ingen path, argumenter eller request body.\n'
printf 'Ingen generisk process/action, installasjon, shell, filer, kommandoer eller fjernstyring.\n'
printf 'Eksempel: --capability storage --capability remote-desktop\n'
printf 'Tillatt capability: compute, storage, display, remote-desktop\n\n'
exec python3 ./rah-node-agent.py --allow-lan "$@"
