"""Exercise the real Windows PowerShell client against loopback fault servers."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
HELLO = dict(ok=True, product='RAH Home Node Agent', version=2,
             computerName='TEST', pairingRequired=True)
HEALTH = dict(ok=True, status='ready', computerName='TEST', utc='2026-09-15T12:00:00Z')


def line(value):
    return json.dumps(value).encode() + b'\n'


def check(name, payload=None, *, mode='reply', action='hello', expected=None,
          timeout_ms=15000, token='ab' * 32):
    with tempfile.TemporaryDirectory(prefix='rah-client-fault-') as home:
        env = dict(os.environ, LOCALAPPDATA=home)
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0))
        listener.listen(1)
        listener.settimeout(0.2)
        port = listener.getsockname()[1]
        peers = Path(home, 'RAH', 'home-node-peers.json')
        peers.parent.mkdir()
        peers.write_text(json.dumps(dict(version=1, peers=[dict(
            key=f'127.0.0.1:{port}', token=token, computerName='TEST',
            pairedAt='2026-09-15T12:00:00Z')])), encoding='utf-8')
        stop = threading.Event()
        received = threading.Event()
        request_at = []
        errors = []

        def serve():
            try:
                while not stop.is_set():
                    try:
                        conn, _ = listener.accept()
                        break
                    except socket.timeout:
                        continue
                else:
                    return
                with conn:
                    received.set()
                    conn.settimeout(3)
                    request = b''
                    while not request.endswith(b'\n'):
                        chunk = conn.recv(1024)
                        if not chunk:
                            raise AssertionError('client closed before request')
                        request += chunk
                    assert json.loads(request)['action'] == action
                    request_at.append(time.monotonic())
                    if mode == 'silent':
                        stop.wait(12)
                    elif mode == 'drip':
                        # Each byte is inside the old 5-second per-read timeout.
                        while not stop.wait(0.2):
                            conn.sendall(b' ')
                    else:
                        conn.sendall(payload)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass  # Expected when the client rejects a reply or hits its deadline.
            except Exception as exc:
                errors.append(exc)

        worker = threading.Thread(target=serve, daemon=True)
        worker.start()
        try:
            result = subprocess.run([
                'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', str(ROOT / 'RAH-HOME-NODE-CLIENT.ps1'),
                '-NodeAddress', '127.0.0.1', '-Port', str(port),
                '-Action', action, '-TimeoutMs', str(timeout_ms),
            ], env=env, capture_output=True, timeout=25)
            finished = time.monotonic()
        finally:
            stop.set()
            worker.join(4)
            listener.close()
        assert not worker.is_alive(), f'{name}: server did not stop'
        assert not errors, f'{name}: server errors: {errors}'
        output = (result.stdout + result.stderr).decode(errors='replace')
        if expected is None:
            assert result.returncode == 0, f'{name}: {output}'
            assert json.loads(result.stdout)['ok'] is True
        else:
            assert result.returncode != 0, f'{name}: unexpectedly accepted'
            assert expected in output, f'{name}: wrong failure: {output}'
        if mode in ('silent', 'drip'):
            assert request_at, f'{name}: no request reached server'
            elapsed = finished - request_at[0]
            assert 0.8 <= elapsed < 6, f'{name}: request took {elapsed:.2f}s'
        if token == 'invalid-token':
            assert not received.is_set(), 'corrupt token caused a network connection'
        else:
            assert received.is_set(), f'{name}: no connection'
        print(f'PASS: {name}')


def main():
    check('valid hello', line(HELLO))
    check('valid health', line(HEALTH), action='health')
    check('silent server deadline', mode='silent', timeout_ms=1200,
          expected='node-request-timeout')
    check('dripping server deadline', mode='drip', timeout_ms=1200,
          expected='node-request-timeout')
    check('oversized response', b'A' * (1048576 + 1) + b'\n',
          expected='node-response-too-large')
    check('invalid UTF-8', b'\xff\n', expected='invalid-node-utf8')
    check('invalid JSON', b'{broken\n', expected='ugyldig JSON')
    check('wrong hello shape', line(dict(ok=True)), expected='Ugyldig hello-svar')
    check('wrong health shape', line(dict(ok=True)), action='health',
          expected='Ugyldig health-svar')
    check('nonboolean action status', line(dict(HEALTH, ok='true')), action='health',
          expected='mangler boolsk ok')
    check('invalid cache token never connects', action='health', token='invalid-token',
          expected='not-paired-or-invalid-local-token')


if __name__ == '__main__':
    main()
