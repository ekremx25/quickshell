import QtQuick
import QtQuick.Layouts
import Quickshell

// Cpu klasöründeki dosyaları (Usage ve Temp) içeri al
import "./Cpu"

RowLayout {
    spacing: 0

    // 1. SAAT (Yeşil)
    TimeModule {}

    // 2. CPU KULLANIMI (Mavi - Geri geldi!)
    Usage {}

    // 3. RAM (Mor)
    RamModule {}

    // 4. SICAKLIK (Pembe)
    CpuTemp {}
}
