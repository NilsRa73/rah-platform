#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT - FIXED ACTION ALLOWLIST + ONE-TIME CHALLENGE\n'
printf '=======================================================\n'
printf 'Starter /health og /actions paa lokalnett, port 18766.\n'
printf '/storage finnes bare med --capability storage.\n'
printf '/launch/rustdesk og /handoff/rustdesk annonseres bare med --capability remote-desktop og lokal RustDesk.\n'
printf 'Handoff tar kun validert RustDesk peerId. Ingen password, path, server, key eller frie argumenter.\n'
echo "Hver action krever fersk 60-sekunders single-use challenge fra /actions; challenge lagres ikke."
printf 'Ingen generisk process/action, installasjon, shell, filer, kommandoer eller native fjernstyring.\n'
printf 'Eksempel: --capability storage --capability remote-desktop\n'
printf 'Tillatt capability: compute, storage, display, remote-desktop\n\n'
exec python3 ./rah-node-agent.py --allow-lan "$@"
