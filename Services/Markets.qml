pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/Log.js" as Log

Singleton {
    id: service

    readonly property string cachePath: Core.PathService.cachePath("markets.json")
    property real usdTryBuying: 0
    property real usdTrySelling: 0
    property string tcmbDate: ""
    property real bitcoinUsd: 0
    property real bitcoinTry: 0
    property real bitcoinChange: 0
    property real ethereumUsd: 0
    property real ethereumTry: 0
    property real ethereumChange: 0
    property double lastUpdatedEpoch: 0
    property bool refreshing: false
    property string statusText: "Waiting for market data..."
    property bool hasData: usdTrySelling > 0 || bitcoinUsd > 0 || ethereumUsd > 0
    property bool cryptoDone: false
    property bool currencyDone: false
    property bool cryptoSuccess: false
    property bool currencySuccess: false
    property var converterCurrencies: [
        { code: "USD", name: "United States Dollar", symbol: "$" },
        { code: "PHP", name: "Philippine Peso", symbol: "₱" },
        { code: "TRY", name: "Turkish Lira", symbol: "₺" },
        { code: "EUR", name: "Euro", symbol: "€" },
        { code: "GBP", name: "British Pound", symbol: "£" },
        { code: "JPY", name: "Japanese Yen", symbol: "¥" },
        { code: "QAR", name: "Qatari Riyal", symbol: "ر.ق" },
        { code: "SAR", name: "Saudi Riyal", symbol: "ر.س" }
    ]
    property string converterFrom: "USD"
    property string converterTo: "PHP"
    property real converterRate: 0
    property string converterDate: ""
    property bool converterLoading: false
    property string converterStatus: ""
    property var converterRateCache: ({})
    property bool currenciesLoading: false

    function ensureRegionalCurrencies(currencies) {
        var list = Array.isArray(currencies)
            ? JSON.parse(JSON.stringify(currencies))
            : [];
        var required = [
            { code: "QAR", name: "Qatari Riyal", symbol: "ر.ق" },
            { code: "SAR", name: "Saudi Riyal", symbol: "ر.س" }
        ];
        for (var i = 0; i < required.length; i++) {
            var found = false;
            for (var j = 0; j < list.length; j++) {
                if (String(list[j].code || "").toUpperCase() === required[i].code) {
                    found = true;
                    break;
                }
            }
            if (!found) list.push(required[i]);
        }
        list.sort(function(a, b) { return String(a.code).localeCompare(String(b.code)); });
        return list;
    }

    function refresh() {
        if (refreshing) return;
        refreshing = true;
        cryptoDone = false;
        currencyDone = false;
        cryptoSuccess = false;
        currencySuccess = false;
        statusText = "Updating market data...";

        cryptoProc.output = "";
        currencyProc.output = "";
        cryptoProc.running = true;
        currencyProc.running = true;
    }

    function finishPart(part, success) {
        if (part === "crypto") {
            cryptoDone = true;
            cryptoSuccess = success;
        }
        if (part === "currency") {
            currencyDone = true;
            currencySuccess = success;
        }
        if (!cryptoDone || !currencyDone) return;
        refreshing = false;
        if (hasData) {
            if (cryptoSuccess || currencySuccess) {
                lastUpdatedEpoch = Date.now();
                saveCache();
            }
            statusText = cryptoSuccess && currencySuccess
                ? "Market data is up to date."
                : "Some values use the last successful update.";
        } else {
            statusText = "Market data is unavailable. Check your internet connection.";
        }
    }

    function saveCache() {
        cacheStore.save({
            usdTryBuying: usdTryBuying,
            usdTrySelling: usdTrySelling,
            tcmbDate: tcmbDate,
            bitcoinUsd: bitcoinUsd,
            bitcoinTry: bitcoinTry,
            bitcoinChange: bitcoinChange,
            ethereumUsd: ethereumUsd,
            ethereumTry: ethereumTry,
            ethereumChange: ethereumChange,
            lastUpdatedEpoch: lastUpdatedEpoch,
            converterCurrencies: converterCurrencies,
            converterFrom: converterFrom,
            converterTo: converterTo,
            converterRate: converterRate,
            converterDate: converterDate,
            converterRateCache: converterRateCache
        });
    }

    function ensureConverterCurrencies() {
        if (currenciesLoading || converterCurrencies.length > 20) return;
        currenciesLoading = true;
        currenciesProc.output = "";
        currenciesProc.running = true;
    }

    function setConverterPair(fromCode, toCode) {
        converterFrom = String(fromCode || "USD").toUpperCase();
        converterTo = String(toCode || "PHP").toUpperCase();
        requestConversion();
    }

    function swapConverterPair() {
        var previousFrom = converterFrom;
        converterFrom = converterTo;
        converterTo = previousFrom;
        requestConversion();
    }

    function requestConversion() {
        if (converterFrom === converterTo) {
            converterRate = 1;
            converterDate = Qt.formatDate(new Date(), "yyyy-MM-dd");
            converterStatus = "Same currency";
            saveCache();
            return;
        }

        var key = converterFrom + "_" + converterTo;
        var cached = converterRateCache[key];
        if (cached && Number(cached.rate) > 0) {
            converterRate = Number(cached.rate);
            converterDate = String(cached.date || "");
            converterStatus = "Showing saved reference rate";
        }

        if (converterLoading) conversionProc.running = false;
        converterLoading = true;
        converterStatus = "Updating exchange rate...";
        conversionProc.output = "";
        conversionProc.command = ["curl", "-fsS", "--connect-timeout", "8", "--max-time", "20",
            "https://api.frankfurter.dev/v2/rate/" + converterFrom + "/" + converterTo];
        conversionProc.running = true;
    }

    function currencySymbol(code) {
        for (var i = 0; i < converterCurrencies.length; i++) {
            if (converterCurrencies[i].code === code) return converterCurrencies[i].symbol || code;
        }
        return code;
    }

    function currencyName(code) {
        for (var i = 0; i < converterCurrencies.length; i++) {
            if (converterCurrencies[i].code === code) return converterCurrencies[i].name || code;
        }
        return code;
    }

    function convertedAmount(amount) {
        var value = Number(amount);
        if (!isFinite(value) || value < 0 || converterRate <= 0) return 0;
        return value * converterRate;
    }

    function formatConverted(value) {
        var number = Number(value);
        if (!isFinite(number)) return "--";
        var absolute = Math.abs(number);
        var digits = absolute >= 100 ? 2 : absolute >= 1 ? 4 : 6;
        return number.toLocaleString(Qt.locale(), "f", digits);
    }

    function parseXmlValue(xml, tag) {
        var expression = new RegExp("<" + tag + ">(.*?)</" + tag + ">");
        var match = expression.exec(xml);
        return match && match.length > 1 ? Number(match[1]) : 0;
    }

    function formatNumber(value, digits) {
        var number = Number(value || 0);
        if (!isFinite(number) || number <= 0) return "--";
        var fixed = number.toFixed(digits);
        var parts = fixed.split(".");
        var integer = parts[0];
        var grouped = "";
        while (integer.length > 3) {
            grouped = "," + integer.slice(-3) + grouped;
            integer = integer.slice(0, -3);
        }
        grouped = integer + grouped;
        return digits > 0 ? grouped + "." + parts[1] : grouped;
    }

    function changeText(value) {
        var number = Number(value || 0);
        return (number >= 0 ? "+" : "") + number.toFixed(2) + "%";
    }

    function updateTimeText() {
        if (lastUpdatedEpoch <= 0) return "Never updated";
        return "Updated " + Qt.formatDateTime(new Date(lastUpdatedEpoch), "dd MMM · HH:mm");
    }

    Component.onCompleted: {
        cacheStore.load();
        initialRefresh.start();
        converterInitialRefresh.start();
    }

    Timer {
        id: initialRefresh
        interval: 700
        repeat: false
        onTriggered: service.refresh()
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: service.refresh()
    }

    Timer {
        id: converterInitialRefresh
        interval: 1200
        repeat: false
        onTriggered: {
            service.ensureConverterCurrencies();
            service.requestConversion();
        }
    }

    Process {
        id: cryptoProc
        property string output: ""
        command: ["curl", "-fsS", "--max-time", "15",
            "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd,try&include_24hr_change=true&include_last_updated_at=true"]
        stdout: SplitParser { onRead: data => cryptoProc.output += data }
        stderr: SplitParser { onRead: data => Log.warn("MarketsService", "CoinGecko: " + data) }
        onExited: function(exitCode) {
            var success = false;
            if (exitCode === 0 && output.trim().length > 0) {
                try {
                    var data = JSON.parse(output);
                    if (data.bitcoin && data.ethereum) {
                        service.bitcoinUsd = Number(data.bitcoin.usd || 0);
                        service.bitcoinTry = Number(data.bitcoin.try || 0);
                        service.bitcoinChange = Number(data.bitcoin.usd_24h_change || 0);
                        service.ethereumUsd = Number(data.ethereum.usd || 0);
                        service.ethereumTry = Number(data.ethereum.try || 0);
                        service.ethereumChange = Number(data.ethereum.usd_24h_change || 0);
                        success = true;
                    }
                } catch (e) {
                    Log.warn("MarketsService", "CoinGecko parse error: " + e);
                }
            }
            output = "";
            service.finishPart("crypto", success);
        }
    }

    Process {
        id: currencyProc
        property string output: ""
        command: ["sh", "-c",
            "curl -fsS --connect-timeout 8 --max-time 30 --retry 2 --retry-delay 2 https://www.tcmb.gov.tr/kurlar/today.xml || curl -fsS --connect-timeout 8 --max-time 30 https://tcmb.gov.tr/kurlar/today.xml"]
        stdout: SplitParser { onRead: data => currencyProc.output += data }
        stderr: SplitParser { onRead: data => Log.warn("MarketsService", "TCMB: " + data) }
        onExited: function(exitCode) {
            var success = false;
            if (exitCode === 0 && output.trim().length > 0) {
                try {
                    var blockMatch = /<Currency[^>]*(?:CurrencyCode|Kod)="USD"[^>]*>([\s\S]*?)<\/Currency>/.exec(output);
                    var dateMatch = /<Tarih_Date[^>]*Tarih="([^"]+)"/.exec(output);
                    if (blockMatch) {
                        service.usdTryBuying = service.parseXmlValue(blockMatch[1], "ForexBuying");
                        service.usdTrySelling = service.parseXmlValue(blockMatch[1], "ForexSelling");
                        service.tcmbDate = dateMatch && dateMatch.length > 1 ? dateMatch[1] : "";
                        success = service.usdTrySelling > 0;
                    }
                } catch (e) {
                    Log.warn("MarketsService", "TCMB parse error: " + e);
                }
            }
            output = "";
            service.finishPart("currency", success);
        }
    }

    Process {
        id: currenciesProc
        property string output: ""
        command: ["curl", "-fsS", "--connect-timeout", "8", "--max-time", "25",
            "https://api.frankfurter.dev/v2/currencies"]
        stdout: SplitParser { onRead: data => currenciesProc.output += data }
        stderr: SplitParser { onRead: data => Log.warn("MarketsService", "Currencies: " + data) }
        onExited: function(exitCode) {
            service.currenciesLoading = false;
            if (exitCode === 0 && output.trim().length > 0) {
                try {
                    var response = JSON.parse(output);
                    if (Array.isArray(response) && response.length > 0) {
                        var latestEndDate = "";
                        for (var i = 0; i < response.length; i++) {
                            if (String(response[i].end_date || "") > latestEndDate) latestEndDate = String(response[i].end_date);
                        }
                        var current = response.filter(function(entry) {
                            return entry.iso_code && String(entry.end_date || "") === latestEndDate;
                        }).map(function(entry) {
                            return {
                                code: String(entry.iso_code),
                                name: String(entry.name || entry.iso_code),
                                symbol: String(entry.symbol || entry.iso_code)
                            };
                        });
                        current.sort(function(a, b) { return a.code.localeCompare(b.code); });
                        if (current.length > 20) {
                            service.converterCurrencies = service.ensureRegionalCurrencies(current);
                            service.saveCache();
                        }
                    }
                } catch (e) {
                    Log.warn("MarketsService", "Currency list parse error: " + e);
                }
            }
            output = "";
        }
    }

    Process {
        id: conversionProc
        property string output: ""
        command: []
        stdout: SplitParser { onRead: data => conversionProc.output += data }
        stderr: SplitParser { onRead: data => Log.warn("MarketsService", "Conversion: " + data) }
        onExited: function(exitCode) {
            service.converterLoading = false;
            var success = false;
            if (exitCode === 0 && output.trim().length > 0) {
                try {
                    var response = JSON.parse(output);
                    var rate = Number(response.rate || 0);
                    if (rate > 0 && response.base === service.converterFrom && response.quote === service.converterTo) {
                        service.converterRate = rate;
                        service.converterDate = String(response.date || "");
                        var next = JSON.parse(JSON.stringify(service.converterRateCache || {}));
                        next[service.converterFrom + "_" + service.converterTo] = {
                            rate: rate,
                            date: service.converterDate
                        };
                        service.converterRateCache = next;
                        service.converterStatus = "Reference rate is up to date";
                        service.saveCache();
                        success = true;
                    }
                } catch (e) {
                    Log.warn("MarketsService", "Conversion parse error: " + e);
                }
            }
            if (!success) {
                service.converterStatus = service.converterRate > 0
                    ? "Network unavailable — using saved rate"
                    : "Exchange rate unavailable";
            }
            output = "";
        }
    }

    Core.JsonDataStore {
        id: cacheStore
        path: service.cachePath
        defaultValue: ({})
        onLoadedValue: function(data) {
            if (data.usdTryBuying) service.usdTryBuying = Number(data.usdTryBuying);
            if (data.usdTrySelling) service.usdTrySelling = Number(data.usdTrySelling);
            if (data.tcmbDate) service.tcmbDate = String(data.tcmbDate);
            if (data.bitcoinUsd) service.bitcoinUsd = Number(data.bitcoinUsd);
            if (data.bitcoinTry) service.bitcoinTry = Number(data.bitcoinTry);
            if (data.bitcoinChange !== undefined) service.bitcoinChange = Number(data.bitcoinChange);
            if (data.ethereumUsd) service.ethereumUsd = Number(data.ethereumUsd);
            if (data.ethereumTry) service.ethereumTry = Number(data.ethereumTry);
            if (data.ethereumChange !== undefined) service.ethereumChange = Number(data.ethereumChange);
            if (data.lastUpdatedEpoch) service.lastUpdatedEpoch = Number(data.lastUpdatedEpoch);
            if (Array.isArray(data.converterCurrencies) && data.converterCurrencies.length > 0) {
                service.converterCurrencies = service.ensureRegionalCurrencies(data.converterCurrencies);
            } else {
                service.converterCurrencies = service.ensureRegionalCurrencies(service.converterCurrencies);
            }
            if (data.converterFrom) service.converterFrom = String(data.converterFrom);
            if (data.converterTo) service.converterTo = String(data.converterTo);
            if (data.converterRate) service.converterRate = Number(data.converterRate);
            if (data.converterDate) service.converterDate = String(data.converterDate);
            if (data.converterRateCache && typeof data.converterRateCache === "object") service.converterRateCache = data.converterRateCache;
            if (service.hasData) service.statusText = "Showing the last successful update.";
        }
    }
}
