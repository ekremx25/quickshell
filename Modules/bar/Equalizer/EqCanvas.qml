import QtQuick

// EQ frequency curve Canvas.
// Runs independently from Equalizer.qml; all state is passed in as properties.
Canvas {
    id: canvas

    property var   eqBands:       []
    property real  wavePhase:     0
    property color eqAccent:      "transparent"
    property color waveGlowColor: "transparent"
    property color waveLineColor: "transparent"

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!eqBands || eqBands.length === 0) return;

        // Convert frequency bands to canvas coordinates
        var anchors = [];
        for (var i = 0; i < eqBands.length; i++) {
            var anchorX     = (width / Math.max(1, eqBands.length - 1)) * i;
            var anchorRatio = (eqBands[i] + 12) / 24.0;
            var anchorY     = (1 - anchorRatio) * (height - 12) + 6;
            anchors.push({ x: anchorX, y: anchorY });
        }
        if (anchors.length < 2) return;

        // Generate wave samples (back + front layer)
        var backSamples  = [];
        var frontSamples = [];
        var sampleCount  = Math.max(48, Math.floor(width / 6));

        for (var s = 0; s <= sampleCount; s++) {
            var t       = s / sampleCount;
            var fx      = t * width;
            var scaled  = t * (anchors.length - 1);
            var left    = Math.floor(scaled);
            var right   = Math.min(anchors.length - 1, left + 1);
            var blend   = scaled - left;
            var baseY   = anchors[left].y * (1 - blend) + anchors[right].y * blend;
            var ampA    = 1.15 + (Math.abs(eqBands[left])  * 0.22);
            var ampB    = 1.15 + (Math.abs(eqBands[right]) * 0.22);
            var amp     = ampA * (1 - blend) + ampB * blend;

            var backRipple  = Math.sin((t * 7.0)  + (wavePhase * 0.75)) * (amp * 0.95);
            backRipple     += Math.sin((t * 17.0) - (wavePhase * 1.05)) * (amp * 0.18);
            backSamples.push({ x: fx, y: baseY + backRipple + 0.8 });

            var frontRipple  = Math.sin((t * 8.4)  + (wavePhase * 1.05)) * (amp * 0.88);
            frontRipple     += Math.sin((t * 22.0) - (wavePhase * 1.55)) * (amp * 0.14);
            frontSamples.push({ x: fx, y: baseY + frontRipple });
        }

        // Background mist layer
        var mist = ctx.createLinearGradient(0, height * 0.30, width, height * 0.68);
        mist.addColorStop(0.0, "rgba(180, 245, 245, 0.01)");
        mist.addColorStop(0.5, "rgba(180, 245, 245, 0.06)");
        mist.addColorStop(1.0, "rgba(180, 245, 245, 0.01)");
        ctx.fillStyle = mist;
        ctx.fillRect(0, height * 0.30, width, height * 0.30);

        // Shadow curve (thick, translucent)
        ctx.beginPath();
        ctx.moveTo(backSamples[0].x, backSamples[0].y);
        for (var p = 1; p < backSamples.length; p++) {
            ctx.lineTo(backSamples[p].x, backSamples[p].y);
        }
        ctx.lineWidth   = 6.5;
        ctx.strokeStyle = Qt.rgba(eqAccent.r, eqAccent.g, eqAccent.b, 0.10);
        ctx.stroke();

        // Glow curve (middle)
        ctx.beginPath();
        ctx.moveTo(frontSamples[0].x, frontSamples[0].y);
        for (var j = 1; j < frontSamples.length; j++) {
            ctx.lineTo(frontSamples[j].x, frontSamples[j].y);
        }
        ctx.lineWidth   = 4.2;
        ctx.strokeStyle = waveGlowColor;
        ctx.stroke();

        // Main curve (thin, sharp)
        ctx.beginPath();
        ctx.moveTo(frontSamples[0].x, frontSamples[0].y);
        for (var k = 1; k < frontSamples.length; k++) {
            ctx.lineTo(frontSamples[k].x, frontSamples[k].y);
        }
        ctx.lineWidth   = 1.35;
        ctx.strokeStyle = waveLineColor;
        ctx.stroke();

        // Band anchor glows
        for (var a = 0; a < anchors.length; a++) {
            var softGrad = ctx.createRadialGradient(
                anchors[a].x, anchors[a].y, 0,
                anchors[a].x, anchors[a].y, 18
            );
            softGrad.addColorStop(0.0, "rgba(213, 255, 255, 0.08)");
            softGrad.addColorStop(1.0, "rgba(213, 255, 255, 0.00)");
            ctx.fillStyle = softGrad;
            ctx.beginPath();
            ctx.arc(anchors[a].x, anchors[a].y, 18, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    onEqBandsChanged:   requestPaint()
    onWavePhaseChanged: requestPaint()
    Component.onCompleted: requestPaint()
}
