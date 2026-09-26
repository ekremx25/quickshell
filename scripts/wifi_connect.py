"""Connect using stdin for secrets; never return nmcli output (it may contain secrets)."""
import json
import os
import subprocess
import sys


def connect(request):
    ssid = request.get("ssid")
    password = request.get("password", "")
    if (not isinstance(ssid, str) or not ssid or ssid.startswith("-")
            or not isinstance(password, str)
            or any(c in ssid + password for c in "\x00\r\n")):
        return {"ok": False, "message": "Invalid network name or password."}
    command = ["nmcli", "--wait", "30"]
    if password:
        command.append("--ask")
    command += ["device", "wifi", "connect", ssid]
    try:
        result = subprocess.run(command, input=password + "\n" if password else "",
                                capture_output=True, text=True, timeout=40,
                                env=dict(os.environ, LC_ALL="C"))
    except subprocess.TimeoutExpired:
        return {"ok": False, "message": "Connection timed out. Try again."}
    except OSError:
        return {"ok": False, "message": "Could not start NetworkManager's nmcli command."}
    if result.returncode == 0:
        return {"ok": True, "message": "Connected."}
    messages = {
        3: "Connection timed out. Try again.",
        4: "Connection failed. Check the password and network availability.",
        8: "NetworkManager is not running.",
        10: "The Wi-Fi network is no longer available.",
    }
    return {"ok": False, "message": messages.get(result.returncode,
            "Connection failed. Check network permissions and try again.")}


def main():
    try:
        request = json.loads(sys.stdin.readline())
        response = connect(request) if isinstance(request, dict) else {"ok": False, "message": "Invalid connection request."}
    except (ValueError, TypeError):
        response = {"ok": False, "message": "Invalid connection request."}
    print(json.dumps(response))
    return 0 if response["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
