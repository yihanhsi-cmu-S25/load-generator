import http.server
import socketserver
import time
import os
import argparse
import logging
import threading

# 配置日誌
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class LoadHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"Hello, Load Generator!")

        # 解析 URL 中的參數
        parsed_path = self.path.split('?')
        params = {}
        if len(parsed_path) > 1:
            query_string = parsed_path[1]
            for param in query_string.split('&'):
                if '=' in param:
                    key, value = param.split('=')
                    params[key] = value

        cpu_load_seconds = int(params.get('cpu_load_seconds', os.environ.get('CPU_LOAD_SECONDS', '0')))
        memory_load_mb = int(params.get('memory_load_mb', os.environ.get('MEMORY_LOAD_MB', '0')))
        delay_seconds = float(params.get('delay_seconds', os.environ.get('DELAY_SECONDS', '0')))

        if cpu_load_seconds > 0:
            logging.info(f"Generating CPU load for {cpu_load_seconds} seconds...")
            start_time = time.time()
            while True:
                # 模擬 CPU 密集型運算
                _ = sum(i * i for i in range(10000))
                if time.time() - start_time >= cpu_load_seconds:
                    break
            logging.info("CPU load finished.")

        if memory_load_mb > 0:
            logging.info(f"Generating Memory load of {memory_load_mb} MB...")
            # 模擬記憶體佔用
            try:
                # 每個元素約為 8 bytes (list of integers)
                # 1 MB = 1024 * 1024 bytes
                # 需要的元素數量 = (memory_load_mb * 1024 * 1024) / 8
                self.large_list = [0] * int((memory_load_mb * 1024 * 1024) / 8)
                logging.info(f"Allocated {len(self.large_list) * 8 / (1024*1024):.2f} MB of memory.")
                # 防止 Python 最佳化掉不使用的記憶體
                # 可以在這裡進行一些對 large_list 的操作，例如 sum() 或 iter()
                # 這裡只是簡單地確保它被引用
                _ = len(self.large_list)
            except Exception as e:
                logging.error(f"Memory allocation failed: {e}")
            logging.info("Memory load finished.")
            # 在請求結束後，垃圾回收會釋放記憶體，所以每次請求都會重新分配。
            # 如果要長時間佔用記憶體，需要修改設計。

        if delay_seconds > 0:
            logging.info(f"Introducing delay for {delay_seconds} seconds...")
            time.sleep(delay_seconds)
            logging.info("Delay finished.")

        logging.info("Request processed.")

def run_server(port, bind_address):
    with socketserver.TCPServer((bind_address, port), LoadHandler) as httpd:
        logging.info(f"Serving at {bind_address}:{port}")
        httpd.serve_forever()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simple HTTP Load Generator.")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on.")
    parser.add_argument("--bind", type=str, default="0.0.0.0", help="Address to bind to.")
    args = parser.parse_args()

    run_server(args.port, args.bind)