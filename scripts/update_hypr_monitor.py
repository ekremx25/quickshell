import sys
import os
import re

if len(sys.argv) != 6:
    print("Usage: python3 update_hypr_monitor.py <monitor_name> <res> <hz> <scale> <conf_path>")
    sys.exit(1)

monitor_name = sys.argv[1]
res = sys.argv[2]
hz = sys.argv[3]
scale = sys.argv[4]
conf_path = os.path.expanduser(sys.argv[5])

try:
    with open(conf_path, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print(f"Config file not found: {conf_path}")
    sys.exit(0)

new_lines = []
in_target_block = False
brace_count = 0
found_mode = False
found_scale = False

for i, line in enumerate(lines):
    # check if entering monitorv2 / monitor block
    match_start = re.match(r'^\s*monitor(v2)?\s*\{', line)
    if match_start:
        # scan ahead to verify it is for our monitor
        is_target = False
        for j in range(i, min(i+20, len(lines))):
            if re.search(rf'^\s*output\s*=\s*{re.escape(monitor_name)}\b', lines[j]):
                is_target = True
                break
            if '}' in lines[j]:
                break
        if is_target:
            in_target_block = True
            brace_count = 0
            found_mode = False
            found_scale = False

    append_line = True
    if in_target_block:
        brace_count += line.count('{') - line.count('}')
        
        if re.search(r'^\s*mode\s*=', line):
            indent = line[:len(line) - len(line.lstrip())]
            line = f"{indent}mode = {res}@{hz}\n"
            found_mode = True
        elif re.search(r'^\s*scale\s*=', line):
            indent = line[:len(line) - len(line.lstrip())]
            line = f"{indent}scale = {scale}\n"
            found_scale = True
            
        if brace_count <= 0 and '}' in line:
            in_target_block = False
            indent = "    "
            # Insert missing properties before closing brace
            if not found_mode:
                new_lines.append(f"{indent}mode = {res}@{hz}\n")
            if not found_scale:
                new_lines.append(f"{indent}scale = {scale}\n")

    if append_line:
        new_lines.append(line)

with open(conf_path, 'w') as f:
    f.writelines(new_lines)

print(f"Updated {monitor_name} to {res}@{hz} scale {scale}")
