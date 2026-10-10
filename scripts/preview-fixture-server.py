"""Serve deterministic pages for real Apple Link Presentation integration tests."""

import argparse
import json
import struct
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


image_width = 640
image_height = 360
image_pixels = b"".join(
    b"\x00" + bytes(channel for column in range(image_width)
                    for channel in (column % 256, row % 256, (column ^ row) % 256))
    for row in range(image_height)
)
image_data = (
    b"\x89PNG\r\n\x1a\n"
    + png_chunk(b"IHDR", struct.pack(">IIBBBBB", image_width, image_height, 8, 2, 0, 0, 0))
    + png_chunk(b"IDAT", zlib.compress(image_pixels))
    + png_chunk(b"IEND", b"")
)


class PreviewHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/image.png":
            content = image_data
            content_type = "image/png"
        elif self.path in ("/image", "/plain"):
            title = "Planner image preview" if self.path == "/image" else "Planner plain preview"
            image_tag = ""
            if self.path == "/image":
                image_tag = (
                    f'<meta property="og:image" content="{fixture_url}/image.png">'
                    '<meta property="og:image:width" content="640">'
                    '<meta property="og:image:height" content="360">'
                )
            content = (
                f'<!doctype html><html><head><title>{title}</title>'
                f'<meta property="og:title" content="{title}">{image_tag}'
                f'</head><body><h1>{title}</h1></body></html>'
            ).encode()
            content_type = "text/html; charset=utf-8"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, message, *arguments):
        print(json.dumps({"request": message % arguments}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=44555)
    arguments = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", arguments.port), PreviewHandler)
    fixture_url = f"http://127.0.0.1:{server.server_port}"
    print(json.dumps({"url": fixture_url}), flush=True)
    server.serve_forever()
