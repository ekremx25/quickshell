#!/usr/bin/env python3

import subprocess
import sys

def get_cpu_temp():
    try:
        result = subprocess.check_output(
            ["sensors", "k10temp-pci-00c3", "-u"], text=True
        )
        for line in result.splitlines():
            if "Tctl:" in line:
                temp = line.split()[1]
                temp = temp.replace("+", "")  # + işaretini kaldır (isteğe göre kaldır)
                return temp  # Sadece sayı döner, QML °C ekler
    except:
        pass
    return "--"

if __name__ == "__main__":
    print(get_cpu_temp())
    sys.stdout.flush()
