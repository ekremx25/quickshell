.pragma library

// DEBUG_ENABLED = true yaparak debug() çıktılarını aktif edebilirsin.
// Üretimde false bırak — warn/error her zaman çıktı verir.
var DEBUG_ENABLED = false;

function setDebugEnabled(enabled) {
    DEBUG_ENABLED = !!enabled;
}

// Geliştirme sırasında detaylı bilgi için. DEBUG_ENABLED = false ise bastırılır.
function debug(scope, message) {
    if (!DEBUG_ENABLED) return;
    console.log("[DBG][" + scope + "] " + message);
}

// Beklenen ama önemli olaylar için (servis başlatma, config yükleme vb.)
function info(scope, message) {
    console.log("[INF][" + scope + "] " + message);
}

// Beklenmedik ama kurtarılabilir durumlar için.
function warn(scope, message) {
    console.warn("[WRN][" + scope + "] " + message);
}

// Kritik hatalar için.
function error(scope, message) {
    console.error("[ERR][" + scope + "] " + message);
}
