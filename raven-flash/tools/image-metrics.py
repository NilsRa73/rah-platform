#!/usr/bin/env python3
"""Record actual ISO bytes and optionally compare a pinned previous ISO."""
import argparse
import hashlib
import json
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument('iso', type=pathlib.Path)
parser.add_argument('output', type=pathlib.Path)
parser.add_argument('--baseline', type=pathlib.Path)
a = parser.parse_args()
with a.iso.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
result = {'iso': a.iso.name, 'size_bytes': a.iso.stat().st_size,
          'sha256': digest, 'physical_boot_seconds': None,
          'firmware_boot_test_is_not_a_speed_measurement': True}
if a.baseline:
    old = a.baseline.stat().st_size
    result.update(baseline_iso=a.baseline.name, baseline_bytes=old,
                  saved_bytes=old-result['size_bytes'],
                  saved_percent=round(100*(old-result['size_bytes'])/old, 2))
a.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
