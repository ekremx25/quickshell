import QtQuick
import "../../../Widgets"

Canvas {
    id: root

    property var values: []
    property color lineColor: Theme.systemColor
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.14)
    property real ceiling: 0

    antialiasing: true

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onCeilingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var context = getContext("2d");
        context.clearRect(0, 0, width, height);

        var points = Array.isArray(values) ? values : [];
        if (points.length === 0 || width <= 0 || height <= 0) return;

        var maximum = Number(ceiling);
        if (!isFinite(maximum) || maximum <= 0) {
            maximum = 1;
            for (var i = 0; i < points.length; ++i) {
                var candidate = Number(points[i]);
                if (isFinite(candidate)) maximum = Math.max(maximum, candidate);
            }
            maximum *= 1.12;
        }

        var step = points.length > 1 ? width / (points.length - 1) : width;
        function yFor(value) {
            var normalized = Math.max(0, Math.min(1, Number(value || 0) / maximum));
            return height - normalized * Math.max(1, height - 1);
        }

        context.beginPath();
        context.moveTo(0, height);
        for (var j = 0; j < points.length; ++j)
            context.lineTo(points.length > 1 ? j * step : width, yFor(points[j]));
        context.lineTo(width, height);
        context.closePath();
        context.fillStyle = fillColor;
        context.fill();

        context.beginPath();
        for (var k = 0; k < points.length; ++k) {
            var x = points.length > 1 ? k * step : width;
            var y = yFor(points[k]);
            if (k === 0) context.moveTo(x, y);
            else context.lineTo(x, y);
        }
        context.strokeStyle = lineColor;
        context.lineWidth = 1.5;
        context.lineJoin = "round";
        context.lineCap = "round";
        context.stroke();
    }
}
