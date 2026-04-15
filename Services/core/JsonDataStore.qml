import QtQuick
import "."

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property var defaultValue: ({})
    property var value: ({})
    property string rawText: ""

    // Şema versiyonlama:
    // - schemaVersion: bu store'un beklediği versiyon numarası (varsayılan 0 = versiyonsuz)
    // - migrate(data, fromVersion): eski config'i güncel şemaya dönüştürmek için override et
    //   Örnek kullanım:
    //     schemaVersion: 2
    //     function migrate(data, from) {
    //         if (from < 1) data.newField = "default";
    //         if (from < 2) data.renamedField = data.oldField; delete data.oldField;
    //         return data;
    //     }
    property int schemaVersion: 0

    function migrate(data, fromVersion) {
        // Alt sınıflar override etsin. Varsayılan: dönüşüm yok.
        return data;
    }

    // Yüklenen veriyi doğrular. Geçersiz bir değer varsa düzeltilmiş veriyi döndür.
    // Alt sınıflar override edebilir:
    //   function validate(data) {
    //       if (data.timeout < 0) data.timeout = 0;
    //       if (data.timeout > 3600) data.timeout = 3600;
    //       return data;
    //   }
    function validate(data) {
        return data;
    }

    signal loadedValue(var value, string rawText)
    signal savedValue(var value)
    signal failed(string phase, int exitCode, string details)

    function cloneValue(source) {
        try {
            return JSON.parse(JSON.stringify(source));
        } catch (e) {
            return source;
        }
    }

    function load() {
        textStore.read();
    }

    function save(nextValue) {
        root.value = nextValue;
        root.rawText = JSON.stringify(nextValue, null, 2);
        textStore.write(root.rawText);
    }

    TextDataStore {
        id: textStore
        path: root.path
        onLoaded: text => {
            root.rawText = text;
            if (text.trim().length === 0) {
                root.value = root.cloneValue(root.defaultValue);
                root.loadedValue(root.value, root.rawText);
                return;
            }

            try {
                var parsed = JSON.parse(text);

                // Şema versiyonu kontrolü: config'deki versiyon mevcut beklentiden düşükse migrate et.
                var fileVersion = (typeof parsed._schemaVersion === "number") ? parsed._schemaVersion : 0;
                if (root.schemaVersion > 0 && fileVersion < root.schemaVersion) {
                    parsed = root.migrate(parsed, fileVersion);
                    parsed._schemaVersion = root.schemaVersion;
                    // Migrasyon sonucunu hemen diske yaz.
                    root.rawText = JSON.stringify(parsed, null, 2);
                    textStore.write(root.rawText);
                }

                root.value = root.validate(parsed);
                root.loadedValue(root.value, root.rawText);
            } catch (e) {
                // Parse hatası: default değeri kullan, hata sinyalini path ile birlikte ilet
                root.value = root.cloneValue(root.defaultValue);
                root.failed("parse", -1, String(e) + " [path=" + root.path + "]");
                root.loadedValue(root.value, root.rawText);
            }
        }
        onSaved: {
            root.savedValue(root.value);
        }
        // Okuma/yazma hatasına dosya yolunu ekle; loglarda hangi config
        // dosyasının sorun çıkardığı anında görünür hale gelir.
        onFailed: (phase, exitCode, details) => {
            const info = details.length > 0
                ? details + " [path=" + root.path + "]"
                : "[path=" + root.path + "]";
            root.failed(phase, exitCode, info);
        }
    }
}
