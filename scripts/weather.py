#!/usr/bin/env python3
import json
import time
import os
import urllib.request
import sys
import ssl
import traceback

# ================= Configuration Area =================
CACHE_FILE = "/tmp/qs_weather_cache.json"
ERROR_LOG = "/tmp/qs_weather_error.log"
CACHE_DURATION = 1800
ssl._create_default_https_context = ssl._create_unverified_context


# WMO Weather Code Conversion Table
WEATHER_CODES = {
    0: "Clear",
    1: "Mainly Clear",
    2: "Partly Cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Rime Fog",
    51: "Drizzle",
    53: "Drizzle",
    55: "Drizzle",
    61: "Rain",
    63: "Rain",
    65: "Heavy Rain",
    71: "Snow",
    73: "Snow",
    75: "Heavy Snow",
    80: "Showers",
    81: "Showers",
    82: "Violent Showers",
    95: "Thunderstorm",
    96: "Thunderstorm",
    99: "Thunderstorm",
}


def get_weather_desc(code):
    return WEATHER_CODES.get(code, "Unknown")


def log_error(msg):
    try:
        with open(ERROR_LOG, "a") as f:
            f.write(f"[{time.ctime()}] {msg}\n")
    except:
        pass


def get_current_location():
    # User requested Erzurum explicitly
    # Erzurum coordinates
    return 39.90, 41.27, "Erzurum", True

    # IP Auto-detection (Disabled due to inaccuracy)
    # try:
    #     with urllib.request.urlopen("https://ipapi.co/json/", timeout=3) as response:
    #         content = response.read().decode("utf-8")
    #         if not content:
    #             return None, None, None, False
    #
    #         data = json.loads(content)
    #         if not isinstance(data, dict):
    #             return None, None, None, False
    #
    #         lat = data.get("latitude")
    #         lon = data.get("longitude")
    #         city = data.get("city", "Unknown")
    #
    #         if lat and lon:
    #             return lat, lon, city, True
    # except Exception:
    #     pass
    # return None, None, None, False


def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                data = json.load(f)
                # [Core Fix] Ensure read content is a dictionary, otherwise treat as None
                if isinstance(data, dict):
                    return data
        except Exception as e:
            log_error(f"Cache read error: {e}")
    return None



def save_cache(data):
    try:
        with open(CACHE_FILE, "w") as f:
            f.write(json.dumps(data))
    except Exception as e:
        log_error(f"Cache write error: {e}")


def fetch_open_meteo(lat, lon, city):
    # Request current weather AND daily forecast
    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"
        "&timezone=auto"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Quickshell-Widget"})

    with urllib.request.urlopen(req, timeout=5) as response:
        content = response.read().decode("utf-8")
        if not content:
            raise Exception("Empty Response")

        raw = json.loads(content)
        if not isinstance(raw, dict) or "current" not in raw:
            raise Exception("Invalid API Response")

        # Inject city and extra metadata into the raw response so QML can use it easily
        raw["city"] = city
        raw["timestamp"] = time.time()
        
        # Backward compatibility for the Python script's internal logic if needed, 
        # but primarily we want to return the whole raw structure for QML.
        # We will wrap it in a structure that matches what Weather.qml expects after parsing.
        
        return raw


def main():
    cur_lat, cur_lon, cur_city, loc_success = get_current_location()

    cache = load_cache()
    # [Core Fix] Ensure cache is a dict and contains new data structure keys
    has_valid_cache = isinstance(cache, dict) and "current" in cache and "daily" in cache

    use_cache = False

    if has_valid_cache:
        # cache 此时必为 dict
        cache_age = time.time() - cache.get("timestamp", 0)
        is_fresh = cache_age < CACHE_DURATION

        is_same_location = True
        if loc_success:
            is_same_location = str(cache.get("city")) == str(cur_city)

        if loc_success:
            if is_same_location and is_fresh:
                use_cache = True
        else:
            use_cache = True  # 断网救急

    if use_cache and has_valid_cache:
        print(json.dumps(cache))
    else:
        try:
            if not loc_success:
                raise Exception("Loc Failed")
            weather_data = fetch_open_meteo(cur_lat, cur_lon, cur_city)
            save_cache(weather_data)
            print(json.dumps(weather_data))
        except Exception as e:
            log_error(f"Fetch error: {e}\n{traceback.format_exc()}")
            # 只有当 cache 有效时才使用它做兜底
            if has_valid_cache:
                print(json.dumps(cache))
            else:
                # Complete failure, return default safe data (Compatible with QML structure)
                print(
                    json.dumps(
                        {
                            "current": {
                                "temperature_2m": 0,
                                "relative_humidity_2m": 0,
                                "apparent_temperature": 0,
                                "wind_speed_10m": 0,
                                "weather_code": 0,
                                "is_day": 1
                            },
                            "daily": {
                                "time": ["2000-01-01"] * 7,
                                "temperature_2m_max": [0] * 7,
                                "temperature_2m_min": [0] * 7,
                                "weather_code": [0] * 7,
                                "sunrise": ["00:00"] * 7,
                                "sunset": ["00:00"] * 7
                            },
                            "city": "Error",
                            "timestamp": time.time(),
                        }
                    )
                )


if __name__ == "__main__":
    main()
