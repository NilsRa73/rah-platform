#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
printf '\nRAH NODE AGENT - READ ONLY ENROLLMENT\n'
printf '=====================================\n'
printf 'Starter kun /health paa lokalnett, port 18766.\n'
printf 'Ingen shell, filer, kommandoer eller fjernstyring.\n\n'
exec python3 ./rah-node-agent.py --allow-lan
