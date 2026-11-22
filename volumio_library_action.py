#!/usr/bin/env python3
"""Send a library-management event to Volumio's Socket.IO endpoint."""

import base64
import json
import os
import socket
import struct
import sys


def recv_exact(sock, length):
    result = bytearray()
    while len(result) < length:
        chunk = sock.recv(length - len(result))
        if not chunk:
            raise RuntimeError("incomplete WebSocket frame")
        result.extend(chunk)
    return bytes(result)


def read_frame(sock):
    header = recv_exact(sock, 2)
    first, second = header
    length = second & 0x7f
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]
    mask = recv_exact(sock, 4) if second & 0x80 else b""
    payload = bytearray(recv_exact(sock, length))
    if mask:
        for index in range(length):
            payload[index] ^= mask[index % 4]
    return first & 0x0f, bytes(payload)


def send_frame(sock, payload):
    payload = payload.encode("utf-8")
    mask = os.urandom(4)
    length = len(payload)
    if length < 126:
        header = bytes([0x81, 0x80 | length])
    elif length < 65536:
        header = bytes([0x81, 0x80 | 126]) + struct.pack("!H", length)
    else:
        header = bytes([0x81, 0x80 | 127]) + struct.pack("!Q", length)
    masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    sock.sendall(header + mask + masked)


def wait_for_socketio_open(sock):
    while True:
        frame_type, payload = read_frame(sock)
        if frame_type == 8:
            raise RuntimeError("Volumio closed the WebSocket")
        if frame_type != 1:
            continue
        text = payload.decode("utf-8")
        if text.startswith("0"):
            send_frame(sock, "40")
        elif text.startswith("40"):
            return


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: volumio_library_action.py HOST updateDb [PATH|JSON]")
    host, event = sys.argv[1:3]
    data = sys.argv[3] if len(sys.argv) == 4 else ""
    if event not in ("updateDb", "rescanDb", "addToFavourites"):
        raise SystemExit("unsupported library action")

    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        "GET /socket.io/?EIO=3&transport=websocket HTTP/1.1\r\n"
        f"Host: {host}:3000\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    )
    with socket.create_connection((host, 3000), timeout=5) as sock:
        sock.sendall(request.encode("ascii"))
        response = b""
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(4096)
            if not chunk:
                raise RuntimeError("incomplete WebSocket handshake")
            response += chunk
        if b" 101 " not in response.split(b"\r\n", 1)[0]:
            raise RuntimeError("Volumio WebSocket handshake failed")

        wait_for_socketio_open(sock)
        if event == "updateDb":
            payload = data
        elif event == "addToFavourites":
            payload = json.loads(data)
        else:
            payload = None
        send_frame(sock, "42" + json.dumps([event, payload], separators=(",", ":")))
        sock.settimeout(2)
        try:
            read_frame(sock)
        except socket.timeout:
            pass


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
