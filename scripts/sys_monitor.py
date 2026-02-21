#!/usr/bin/env python3
import json
import psutil
import time
import sys


def get_cpu_temp():
    try:
        temps = psutil.sensors_temperatures()
        if not temps:
            return 0

        # 1. Prioritize finding common CPU temperature labels
        # 'coretemp' is the standard name for Intel CPUs
        # 'k10temp' is the standard name for AMD CPUs
        for name in ["coretemp", "k10temp", "zenpower"]:
            if name in temps:
                for entry in temps[name]:
                    # Usually 'Package id 0' or 'Tctl' is the total CPU temperature
                    if "Package" in entry.label or "Tctl" in entry.label:
                        return entry.current
                # If Package is not found, return the first temperature of the group (usually Core 0)
                return temps[name][0].current

        # 2. If no known CPU is found, iterate through all sensors and return the highest one
        # (CPU is usually one of the hottest components in the system)
        max_temp = 0
        for name, entries in temps.items():
            for entry in entries:
                if entry.current > max_temp:
                    max_temp = entry.current
        return max_temp
    except:
        return 0


def get_sys_info():
    # 1. CPU Usage (block for 0.1 seconds to sample)
    cpu_percent = psutil.cpu_percent(interval=0.1)

    # 2. Memory Usage
    mem = psutil.virtual_memory()
    # Convert to GB, keep one decimal place
    ram_used_gb = round((mem.total - mem.available) / (1024**3), 1)

    # 3. CPU Temperature
    temp = round(get_cpu_temp())

    # 4. Build JSON
    data = {
        "cpu": f"{int(cpu_percent)}%",
        "ram": f"{ram_used_gb}G",
        "temp": f"{temp}°C",
    }

    print(json.dumps(data))


if __name__ == "__main__":
    get_sys_info()
