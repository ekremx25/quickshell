.pragma library

// Monitor layout geometry hesaplamaları.
//
// ctx nesnesi, anlık seçim durumunu taşır:
//   { selectedName: string, selRes: string, selScale: number,
//     selPosX: number, selPosY: number }
//
// Tüm fonksiyonlar saf hesaplama yapar (QML state bağımlılığı yok),
// bu sayede birim testi ve izole kullanım mümkündür.

function effectiveWidth(output, ctx) {
    if (!output) return 0;
    var res   = output.name === ctx.selectedName ? ctx.selRes   : output.res;
    var scale = output.name === ctx.selectedName ? ctx.selScale : parseFloat(output.scale || 1);
    var parts = String(res || "0x0").split("x");
    var width = parts.length > 0 ? parseInt(parts[0]) : 0;
    return scale > 0 ? Math.round(width / scale) : width;
}

function effectiveHeight(output, ctx) {
    if (!output) return 0;
    var res   = output.name === ctx.selectedName ? ctx.selRes   : output.res;
    var scale = output.name === ctx.selectedName ? ctx.selScale : parseFloat(output.scale || 1);
    var parts = String(res || "0x0").split("x");
    var height = parts.length > 1 ? parseInt(parts[1]) : 0;
    return scale > 0 ? Math.round(height / scale) : height;
}

function outputPosX(output, ctx) {
    if (!output) return 0;
    return output.name === ctx.selectedName ? ctx.selPosX : Math.round(output.posX || 0);
}

function outputPosY(output, ctx) {
    if (!output) return 0;
    return output.name === ctx.selectedName ? ctx.selPosY : Math.round(output.posY || 0);
}

function layoutBounds(outputs, ctx) {
    if (!outputs || !outputs.length) return { minX: 0, minY: 0, maxX: 1, maxY: 1 };
    var minX = 0, minY = 0, maxX = 1, maxY = 1;
    for (var i = 0; i < outputs.length; i++) {
        var out = outputs[i];
        var x = outputPosX(out, ctx);
        var y = outputPosY(out, ctx);
        var w = effectiveWidth(out, ctx);
        var h = effectiveHeight(out, ctx);
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x + w);
        maxY = Math.max(maxY, y + h);
    }
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
}

function layoutScale(outputs, ctx, canvasWidth, canvasHeight) {
    var bounds      = layoutBounds(outputs, ctx);
    var totalWidth  = Math.max(1, bounds.maxX - bounds.minX);
    var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
    return Math.min((canvasWidth - 40) / totalWidth, (canvasHeight - 40) / totalHeight);
}

function boxXForOutput(output, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds     = layoutBounds(outputs, ctx);
    var scale      = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
    var offsetX    = (canvasWidth - totalWidth * scale) / 2;
    return offsetX + (outputPosX(output, ctx) - bounds.minX) * scale;
}

function boxYForOutput(output, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds      = layoutBounds(outputs, ctx);
    var scale       = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
    var offsetY     = (canvasHeight - totalHeight * scale) / 2;
    return offsetY + (outputPosY(output, ctx) - bounds.minY) * scale;
}

function boxWidthForOutput(output, outputs, ctx, canvasWidth, canvasHeight) {
    return Math.max(90, effectiveWidth(output, ctx) * layoutScale(outputs, ctx, canvasWidth, canvasHeight));
}

function boxHeightForOutput(output, outputs, ctx, canvasWidth, canvasHeight) {
    return Math.max(60, effectiveHeight(output, ctx) * layoutScale(outputs, ctx, canvasWidth, canvasHeight));
}

function canvasToLayoutX(canvasX, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds     = layoutBounds(outputs, ctx);
    var scale      = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
    var offsetX    = (canvasWidth - totalWidth * scale) / 2;
    return Math.round(((canvasX - offsetX) / Math.max(scale, 0.0001)) + bounds.minX);
}

function canvasToLayoutY(canvasY, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds      = layoutBounds(outputs, ctx);
    var scale       = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
    var offsetY     = (canvasHeight - totalHeight * scale) / 2;
    return Math.round(((canvasY - offsetY) / Math.max(scale, 0.0001)) + bounds.minY);
}

function snapDraggedPosition(outputName, rawX, rawY, outputs, ctx) {
    var target = null;
    for (var i = 0; i < outputs.length; i++) {
        if (outputs[i].name === outputName) { target = outputs[i]; break; }
    }
    if (!target) return { x: rawX, y: rawY };

    var targetW = effectiveWidth(target, ctx);
    var targetH = effectiveHeight(target, ctx);
    var best    = { x: rawX, y: rawY, score: 999999 };

    for (var j = 0; j < outputs.length; j++) {
        var other = outputs[j];
        if (other.name === outputName) continue;

        var otherX  = outputPosX(other, ctx);
        var otherY  = outputPosY(other, ctx);
        var otherW  = effectiveWidth(other, ctx);
        var otherH  = effectiveHeight(other, ctx);
        var dx      = (rawX + targetW / 2) - (otherX + otherW / 2);
        var dy      = (rawY + targetH / 2) - (otherY + otherH / 2);
        var centY   = otherY + Math.round((otherH - targetH) / 2);
        var centX   = otherX + Math.round((otherW - targetW) / 2);
        var candidate;

        if (Math.abs(dx) >= Math.abs(dy)) {
            candidate = dx <= 0
                ? { x: otherX - targetW, y: centY }
                : { x: otherX + otherW,  y: centY };
        } else {
            candidate = dy <= 0
                ? { x: centX, y: otherY - targetH }
                : { x: centX, y: otherY + otherH  };
        }

        var score = Math.abs(rawX - candidate.x) + Math.abs(rawY - candidate.y);
        if (score < best.score) best = { x: candidate.x, y: candidate.y, score: score };
    }

    return { x: best.x, y: best.y };
}
