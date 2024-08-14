#!/usr/bin/python

import http.server
import socketserver
import json
import random
import os


def generate_metrics():
    cpu_usage = random.randint(20, 80)
    memory_usage = random.randint(30, 90)
    return {"cpu_usage": cpu_usage, "memory_usage": memory_usage}

class MetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            metrics_data = generate_metrics()
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            metrics_output = f"chassis_temperature{{instance=\"{phys_server}\"}} {metrics_data['cpu_usage']}\n"
            metrics_output += f"{{instance=\"{phys_server}\"}} {metrics_data['memory_usage']}\n"
            self.wfile.write(metrics_output.encode())
        else:
            super().do_GET()



if __name__ == '__main__':
    ##
    if os.getenv("ILO_USER") is not None and os.getenv("ILO_PASSWORD") is not None and os.getenv("ILO_IPS_LIST_FILE") is not None:
        PORT = 8000
        handler_object = MetricsHandler
        httpd = socketserver.TCPServer(("", PORT), handler_object)
        print("Serving on port", PORT)
        httpd.serve_forever()
    else:
        print("ILO_USER, ILO_PASSWORD and ILO_IPS_LIST_FILE must be defined.")

    ##
    