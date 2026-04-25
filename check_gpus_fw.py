import os
import sys
import requests
import urllib3
import csv
import concurrent.futures

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def process_host(ip, username, password):
    """Worker function to check all 8 GPUs using a persistent session."""
    print(f"Starting to query {ip}...", file=sys.stderr)

    row_data = [ip]

    with requests.Session() as session:
        session.auth = (username, password)
        session.verify = False

        for i in range(1, 9):
            url = f"https://{ip}/redfish/v1/UpdateService/FirmwareInventory/GPU{i}"
            try:
                response = session.get(url, timeout=10)

                if response.status_code == 200:
                    data = response.json()
                    row_data.append(data.get("Version", "N/A"))
                elif response.status_code == 401:
                    row_data.append("Auth Failed")
                elif response.status_code == 404:
                    row_data.append("Not Found")
                else:
                    row_data.append(f"HTTP {response.status_code}")

            except requests.exceptions.Timeout:
                row_data.append("Timeout")
            except requests.exceptions.RequestException:
                row_data.append("Conn Error")

    return row_data

def get_gpu_firmware(ip_list_file, username, password):
    try:
        with open(ip_list_file, 'r') as file:
            ips = [line.strip() for line in file if line.strip()]
    except FileNotFoundError:
        print(f"Error: The file '{ip_list_file}' was not found.", file=sys.stderr)
        sys.exit(1)

    if not ips:
        print("Error: The IP list file is empty.", file=sys.stderr)
        sys.exit(1)

    writer = csv.writer(sys.stdout)

    headers = ["Node_IP", "GPU1", "GPU2", "GPU3", "GPU4", "GPU5", "GPU6", "GPU7", "GPU8"]
    writer.writerow(headers)
    sys.stdout.flush()

    max_workers = min(100, len(ips))

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_ip = {
            executor.submit(process_host, ip, username, password): ip
            for ip in ips
        }

        for future in concurrent.futures.as_completed(future_to_ip):
            try:
                row_data = future.result()
                writer.writerow(row_data)
                sys.stdout.flush()
            except Exception as e:
                ip = future_to_ip[future]
                print(f"Error processing host {ip}: {e}", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_gpus.py <path_to_ip_list_file>", file=sys.stderr)
        sys.exit(1)

    ip_file = sys.argv[1]

    bmc_user = os.getenv("BMC_USER", "admin")
    bmc_password = os.getenv("BMC_PASSWORD")

    if not bmc_password:
        print("Error: The 'BMC_PASSWORD' environment variable is not set.", file=sys.stderr)
        print("Please set it using: export BMC_PASSWORD='your_password'", file=sys.stderr)
        sys.exit(1)

    get_gpu_firmware(ip_file, bmc_user, bmc_password)