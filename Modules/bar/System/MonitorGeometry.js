.pragma library

// Monitor layout geometry calculations.
//
// The ctx object carries the current selection state:
//   { selectedName: string, selRes: string, selScale: number,
//     selPosX: number, selPosY: number }
//
// All functions perform pure calculations (no QML state dependency),
// enabling unit testing and isolated use.

function effectiveWidth(output, ctx) {
    if (!output) return 0;
    var res   = output.name === ctx.selectedName ? ctx.selRes   : output.res;
    var scale = output.name === ctx.selectedName ? ctx.selScale : parseFloat(output.scale || 1);
    var parts = String(res || "0x0").split("x");
    var width = parts.length > 0 ? parseInt(parts[0]) : 0;
    return scale > 0 ? Math.ceil(width / scale) : width;
}

function effectiveHeight(output, ctx) {
    if (!output) return 0;
    var res   = output.name === ctx.selectedName ? ctx.selRes   : output.res;
    var scale = output.name === ctx.selectedName ? ctx.selScale : parseFloat(output.scale || 1);
    var parts = String(res || "0x0").split("x");
    var height = parts.length > 1 ? parseInt(parts[1]) : 0;
    return scale > 0 ? Math.ceil(height / scale) : height;
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

function layoutToCanvasX(layoutX, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds     = layoutBounds(outputs, ctx);
    var scale      = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
    var offsetX    = (canvasWidth - totalWidth * scale) / 2;
    return offsetX + (layoutX - bounds.minX) * scale;
}

function layoutToCanvasY(layoutY, outputs, ctx, canvasWidth, canvasHeight) {
    var bounds      = layoutBounds(outputs, ctx);
    var scale       = layoutScale(outputs, ctx, canvasWidth, canvasHeight);
    var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
    var offsetY     = (canvasHeight - totalHeight * scale) / 2;
    return offsetY + (layoutY - bounds.minY) * scale;
}

function rectsOverlap(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x
        && a.y < b.y + b.h && a.y + a.h > b.y;
}

function resolveOverlap(x, y, width, height, outputName, outputs, ctx) {
    var nextX = x;
    var nextY = y;
    for (var pass = 0; pass < 8; pass++) {
        var hit = null;
        for (var i = 0; i < outputs.length; i++) {
            var other = outputs[i];
            if (other.name === outputName) continue;
            var otherRect = {
                x: outputPosX(other, ctx),
                y: outputPosY(other, ctx),
                w: effectiveWidth(other, ctx),
                h: effectiveHeight(other, ctx)
            };
            if (rectsOverlap({ x: nextX, y: nextY, w: width, h: height }, otherRect)) {
                hit = otherRect;
                break;
            }
        }
        if (!hit) break;

        var pushLeft   = nextX + width - hit.x;
        var pushRight  = hit.x + hit.w - nextX;
        var pushTop    = nextY + height - hit.y;
        var pushBottom = hit.y + hit.h - nextY;
        var smallest   = Math.min(pushLeft, pushRight, pushTop, pushBottom);
        if (smallest === pushLeft) nextX = hit.x - width;
        else if (smallest === pushRight) nextX = hit.x + hit.w;
        else if (smallest === pushTop) nextY = hit.y - height;
        else nextY = hit.y + hit.h;
    }
    return { x: nextX, y: nextY };
}

function snapDraggedPosition(outputName, rawX, rawY, outputs, ctx, threshold) {
    var target = null;
    for (var i = 0; i < outputs.length; i++) {
        if (outputs[i].name === outputName) { target = outputs[i]; break; }
    }
    if (!target) return { x: rawX, y: rawY, guideX: null, guideY: null };

    var targetW = effectiveWidth(target, ctx);
    var targetH = effectiveHeight(target, ctx);
    var snapDistance = Math.max(24, Number(threshold) || 96);
    var centerDistance = Math.max(16, Math.min(36, Math.round(snapDistance * 0.33)));
    var bestX = { distance: snapDistance + 1, value: rawX, guide: null };
    var bestY = { distance: snapDistance + 1, value: rawY, guide: null };

    function considerX(value, distance, guide, centerOnly) {
        if (centerOnly && distance > centerDistance) return;
        if (distance <= bestX.distance) bestX = { distance: distance, value: value, guide: guide };
    }

    function considerY(value, distance, guide) {
        if (distance <= bestY.distance) bestY = { distance: distance, value: value, guide: guide };
    }

    for (var j = 0; j < outputs.length; j++) {
        var other = outputs[j];
        if (other.name === outputName) continue;

        var otherX  = outputPosX(other, ctx);
        var otherY  = outputPosY(other, ctx);
        var otherW  = effectiveWidth(other, ctx);
        var otherH  = effectiveHeight(other, ctx);
        var xCandidates = [
            { value: otherX + otherW, guide: otherX + otherW },
            { value: otherX - targetW, guide: otherX },
            { value: otherX, guide: otherX },
            { value: otherX + otherW - targetW, guide: otherX + otherW }
        ];
        var yCandidates = [
            { value: otherY + otherH, guide: otherY + otherH },
            { value: otherY - targetH, guide: otherY },
            { value: otherY, guide: otherY },
            { value: otherY + otherH - targetH, guide: otherY + otherH }
        ];

        for (var xIndex = 0; xIndex < xCandidates.length; xIndex++) {
            considerX(xCandidates[xIndex].value,
                Math.abs(rawX - xCandidates[xIndex].value), xCandidates[xIndex].guide, false);
        }
        for (var yIndex = 0; yIndex < yCandidates.length; yIndex++) {
            considerY(yCandidates[yIndex].value,
                Math.abs(rawY - yCandidates[yIndex].value), yCandidates[yIndex].guide);
        }

        var nearTopOrBottom = Math.min(Math.abs(rawY + targetH - otherY),
            Math.abs(rawY - (otherY + otherH)));
        if (nearTopOrBottom <= snapDistance) {
            var centeredX = otherX + (otherW - targetW) / 2;
            considerX(centeredX, Math.abs(rawX - centeredX), otherX + otherW / 2, true);
        }
    }

    var snappedX = bestX.distance <= snapDistance ? bestX.value : rawX;
    var snappedY = bestY.distance <= snapDistance ? bestY.value : rawY;
    var resolved = resolveOverlap(snappedX, snappedY, targetW, targetH, outputName, outputs, ctx);
    return {
        x: Math.round(resolved.x),
        y: Math.round(resolved.y),
        guideX: bestX.distance <= snapDistance ? bestX.guide : null,
        guideY: bestY.distance <= snapDistance ? bestY.guide : null
    };
}
