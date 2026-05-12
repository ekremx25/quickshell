import QtQuick
import QtQuick.Layouts
import Quickshell

// Import files from the Cpu folder (Usage and Temp)
import "./Cpu"

RowLayout {
    spacing: 0

    // 1. CLOCK (Green)
    TimeModule {}

    // 2. CPU USAGE (Blue - it's back!)
    Usage {}

    // 3. RAM (Purple)
    RamModule {}

    // 4. TEMPERATURE (Pink)
    CpuTemp {}
}
