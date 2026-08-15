#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT - READ ONLY CAPABILITIES\n'
printf '========================================\n'
printf 'Starter kun /health paa lokalnett, port 18766.\n'
printf 'Ingen shell, filer, kommandoer eller fjernstyring.\n'
printf 'Valgfritt: --capability compute --capability storage\n'
printf 'Tillatt: compute, storage, display, remote-desktop\n\n'
exec python3 ./rah-node-agent.py --allow-lan "$@"
