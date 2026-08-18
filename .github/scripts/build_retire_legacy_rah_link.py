from pathlib import Path

path = Path('desktop-bridge/server.py')
text = path.read_text(encoding='utf-8')

old = '''if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Listening on http://{HOST}:{PORT}")
    if HOST == "0.0.0.0":
        print("LAN mode enabled. Open http://<THIS-PC-IP>:8765/link on the other PC.")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)'''

new = '''if __name__ == "__main__":
    print("RAH Link v1.4/v1.5 is a retired legacy LAN utility.")
    print("No network listener was started and no firewall rule was changed.")
    print("Use raven_bridge.py for the current local Raven Desktop Bridge on 127.0.0.1:18765.")
    raise SystemExit(2)'''

count = text.count(old)
if count != 1:
    raise SystemExit(f'expected exactly one legacy __main__ launch block, got {count}')

text = text.replace(old, new, 1)

if 'app.run(host=HOST, port=PORT' in text:
    raise SystemExit('legacy direct app.run launch remains')
if 'raise SystemExit(2)' not in text:
    raise SystemExit('fail-closed direct execution marker missing')
if 'Use raven_bridge.py' not in text:
    raise SystemExit('canonical Bridge guidance missing')

path.write_text(text, encoding='utf-8')
print('legacy RAH Link direct-execution retirement transform: PASS')
