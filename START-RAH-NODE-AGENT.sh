#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT - READ ONLY ACTION CATALOG\n'
printf '===========================================\n'
printf 'Starter /health og /actions paa lokalnett, port 18766.\n'
printf '/storage finnes bare med --capability storage.\n'
printf 'Ingen generisk action, shell, filer, kommandoer eller fjernstyring.\n'
printf 'Valgfritt: --capability compute --capability storage\n'
printf 'Tillatt: compute, storage, display, remote-desktop\n\n'
exec python3 ./rah-node-agent.py --allow-lan "$@"
