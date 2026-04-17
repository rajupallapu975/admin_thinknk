
import os
import sys
import json
import base64
import http.server
import socketserver
import win32print
import win32ui
from PIL import Image, ImageWin
import io
import tempfile

PORT = 5005

class PrintHandler(http.server.BaseHTTPRequestHandler):
    def _set_headers(self, status_code=200):
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        if self.path == '/status':
            self._set_headers(200)
            self.wfile.write(json.dumps({"status": "ready"}).encode())
        else:
            self._set_headers(404)

    def do_POST(self):
        if self.path == '/print':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data)

                # Extract data
                file_bytes = base64.b64decode(data['file'])
                orientation = data.get('orientation', 'portrait')
                copies = int(data.get('copies', 1))
                file_name = data.get('fileName', 'print_job')

                printer_name = win32print.GetDefaultPrinter()
                print(f"🖨️ Printing {file_name} to {printer_name} ({orientation}) x{copies}")
                
                # Create a temporary file
                with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
                    tmp.write(file_bytes)
                    tmp_path = tmp.name

                # Open imagery
                img = Image.open(tmp_path)
                
                # Professional Hardware DC Logic
                hDC = win32ui.CreateDC()
                hDC.CreatePrinterDC(printer_name)
                
                # Force Hardware Orientation
                # 1 = Portrait, 2 = Landscape
                devmode = win32print.GetPrinter(win32print.OpenPrinter(printer_name), 2)['pDevMode']
                devmode.Orientation = 2 if orientation == 'landscape' else 1
                
                hDC.StartDoc(file_name)
                
                for _ in range(copies):
                    hDC.StartPage()
                    
                    # Calculate Scale to fit A4 exactly
                    printable_area = hDC.GetDeviceCaps(110), hDC.GetDeviceCaps(111) # HORZRES, VERTRES
                    
                    # Scaling logic
                    img_w, img_h = img.size
                    scale = min(printable_area[0]/img_w, printable_area[1]/img_h)
                    new_w = int(img_w * scale)
                    new_h = int(img_h * scale)
                    
                    # Center
                    off_x = (printable_area[0] - new_w) // 2
                    off_y = (printable_area[1] - new_h) // 2
                    
                    dib = ImageWin.Dib(img)
                    dib.draw(hDC.GetHandleOutput(), (off_x, off_y, off_x + new_w, off_y + new_h))
                    
                    hDC.EndPage()
                
                hDC.EndDoc()
                hDC.DeleteDC()
                
                os.remove(tmp_path)

                self._set_headers(200)
                self.wfile.write(json.dumps({"status": "success"}).encode())

            except Exception as e:
                print(f"❌ Error: {e}")
                self._set_headers(500)
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            self._set_headers(404)

print(f"🚀 ThinkInk Hardware Bridge running on http://13.233.76.8:5001")
with socketserver.TCPServer(("", PORT), PrintHandler) as httpd:
    httpd.serve_forever()
