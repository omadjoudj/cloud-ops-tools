#!/usr/bin/env python3
import json
import csv
import sys
import os

def flatten_alert(alert):
    """
    Flattens a single alert object into a flat dictionary
    suitable for a CSV row.
    """
    row = {}

    # 1. Handle top-level simple fields
    row['fingerprint'] = alert.get('fingerprint')
    row['startsAt'] = alert.get('startsAt')
    row['endsAt'] = alert.get('endsAt')
    row['updatedAt'] = alert.get('updatedAt')
    row['generatorURL'] = alert.get('generatorURL')

    # 2. Flatten 'annotations' object
    annotations = alert.get('annotations', {})
    row['annotation_summary'] = annotations.get('summary')
    row['annotation_description'] = annotations.get('description')

    # 3. Flatten 'labels' object
    labels = alert.get('labels', {})
    for key, value in labels.items():
        row[f'label_{key}'] = value

    # 4. Flatten 'status' object
    status = alert.get('status', {})
    row['status_state'] = status.get('state')
    # Join lists with a '|' separator
    row['status_inhibitedBy'] = "|".join(status.get('inhibitedBy', []))
    row['status_silencedBy'] = "|".join(status.get('silencedBy', []))

    # 5. Flatten 'receivers' list
    receivers = alert.get('receivers', [])
    # Extract the 'name' from each receiver object and join them
    receiver_names = [r.get('name') for r in receivers if r.get('name')]
    row['receivers'] = "|".join(receiver_names)

    return row

def main():
    try:
        json_file = sys.argv[1]
    except IndexError:
        print("Error: No input file specified.", file=sys.stderr)
        print("Usage: python convert_to_stdout.py <input.json>", file=sys.stderr)
        sys.exit(1) 

    print(f"Starting conversion of {json_file} to stdout...", file=sys.stderr)

    if not os.path.exists(json_file):
        print(f"Error: Input file not found: {json_file}", file=sys.stderr)
        sys.exit(1)

    with open(json_file, 'r') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error reading JSON file: {e}", file=sys.stderr)
            sys.exit(1)

    if not data or not isinstance(data, list):
        print("Error: JSON data is empty or not in the expected list format.", file=sys.stderr)
        sys.exit(1)

    processed_rows = []
    all_headers = set()

    for alert in data:
        flat_row = flatten_alert(alert)
        processed_rows.append(flat_row)
        all_headers.update(flat_row.keys())

    if not processed_rows:
        print("Warning: No alerts found in the file.", file=sys.stderr)
        sys.exit(0)

    fieldnames = sorted(list(all_headers))

    writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames, lineterminator='\n')

    writer.writeheader()

    writer.writerows(processed_rows)

    print(f"Success! Converted {len(processed_rows)} alerts.", file=sys.stderr)

if __name__ == "__main__":
    main()
