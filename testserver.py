import socketserver
import xxtea
import struct

# KEY = b'+\x95\x9f\x133\r\xe5jX>\x0fvk\x8f0T'
KEY = b'\x13\x9f\x95+j\xe5\r3v\x0f>XT0\x8fk'


class MyTCPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(256).strip()
        print(f"len(data): {len(data)}")
        print(f"{self.client_address} sent:")
        print(data)
        data_unpacked = struct.unpack(f"<{len(data)}B", data)
        data = struct.pack(f"<{len(data_unpacked)}B", *data_unpacked)
        print(f"as little-endian:")
        print(data)
        print("decrypted:")
        print(xxtea.decrypt(data[3:], KEY))


if __name__ == "__main__":
    HOST, PORT = "localhost", 54231

    with socketserver.TCPServer((HOST, PORT), MyTCPHandler) as server:
        server.serve_forever()
