.pragma library

// Pure geometry and auto-layout helpers shared by MonitorsBackend.
// No QML / no Process / no singletons — just math over output objects.

function parseResParts(res) {
    var parts = String(res || "").split("x");
    return {
        width: parts.length > 0 ? parseInt(parts[0]) || 0 : 0,
        height: parts.length > 1 ? parseInt(parts[1]) || 0 : 0
    };
}

function isOutputValid(outObj) {
    if (!outObj) return false;
    var dims = parseResParts(outObj.res);
    return dims.width > 0 && dims.height > 0 && parseFloat(outObj.hz || "0") > 0;
}

function logicalWidth(outObj) {
    var dims = parseResParts(outObj.res);
    var scale = parseFloat(outObj.scale || "1");
    if (!isFinite(scale) || scale <= 0) scale = 1;
    return Math.round(dims.width / scale);
}

function logicalHeight(outObj) {
    var dims = parseResParts(outObj.res);
    var scale = parseFloat(outObj.scale || "1");
    if (!isFinite(scale) || scale <= 0) scale = 1;
    return Math.round(dims.height / scale);
}

function getSavedPosition(outObj, savedConfig) {
    var saved = savedConfig[outObj.name];
    if (saved && saved.posX !== undefined && saved.posY !== undefined) {
        return {
            x: parseInt(saved.posX) || 0,
            y: parseInt(saved.posY) || 0
        };
    }
    return {
        x: Math.round(outObj.posX || 0),
        y: Math.round(outObj.posY || 0)
    };
}

function horizontalOverlapAmount(first, second) {
    var firstLeft = Math.round(first.posX || 0);
    var firstRight = firstLeft + logicalWidth(first);
    var secondLeft = Math.round(second.posX || 0);
    var secondRight = secondLeft + logicalWidth(second);
    return Math.max(0, Math.min(firstRight, secondRight) - Math.max(firstLeft, secondLeft));
}

function verticalOverlapAmount(first, second) {
    var firstTop = Math.round(first.posY || 0);
    var firstBottom = firstTop + logicalHeight(first);
    var secondTop = Math.round(second.posY || 0);
    var secondBottom = secondTop + logicalHeight(second);
    return Math.max(0, Math.min(firstBottom, secondBottom) - Math.max(firstTop, secondTop));
}

function outputsOverlap(first, second) {
    return horizontalOverlapAmount(first, second) > 0 && verticalOverlapAmount(first, second) > 0;
}

function centerYForPlacement(reference, candidate) {
    return Math.round((Math.round(reference.posY || 0) + (logicalHeight(reference) / 2)) - (logicalHeight(candidate) / 2));
}

function centerXForPlacement(reference, candidate) {
    return Math.round((Math.round(reference.posX || 0) + (logicalWidth(reference) / 2)) - (logicalWidth(candidate) / 2));
}

function candidatePlacement(reference, candidate, side) {
    if (side === "left") {
        return {
            x: Math.round(reference.posX || 0) - logicalWidth(candidate),
            y: centerYForPlacement(reference, candidate)
        };
    }
    if (side === "right") {
        return {
            x: Math.round(reference.posX || 0) + logicalWidth(reference),
            y: centerYForPlacement(reference, candidate)
        };
    }
    if (side === "top") {
        return {
            x: centerXForPlacement(reference, candidate),
            y: Math.round(reference.posY || 0) - logicalHeight(candidate)
        };
    }
    return {
        x: centerXForPlacement(reference, candidate),
        y: Math.round(reference.posY || 0) + logicalHeight(reference)
    };
}

function placementScore(reference, candidate, placement, preferredPosition) {
    var prefX = preferredPosition.x;
    var prefY = preferredPosition.y;
    var distance = Math.abs(placement.x - prefX) + Math.abs(placement.y - prefY);
    var centerDistance = Math.abs((placement.x + logicalWidth(candidate) / 2) - (prefX + logicalWidth(candidate) / 2))
        + Math.abs((placement.y + logicalHeight(candidate) / 2) - (prefY + logicalHeight(candidate) / 2));
    var attachPenalty = 0;
    var refCenterX = Math.round(reference.posX || 0) + logicalWidth(reference) / 2;
    var refCenterY = Math.round(reference.posY || 0) + logicalHeight(reference) / 2;
    var prefCenterX = prefX + logicalWidth(candidate) / 2;
    var prefCenterY = prefY + logicalHeight(candidate) / 2;
    var dx = prefCenterX - refCenterX;
    var dy = prefCenterY - refCenterY;
    if ((placement.x < Math.round(reference.posX || 0) && dx > 0)
        || (placement.x >= Math.round(reference.posX || 0) + logicalWidth(reference) && dx < 0)
        || (placement.y < Math.round(reference.posY || 0) && dy > 0)
        || (placement.y >= Math.round(reference.posY || 0) + logicalHeight(reference) && dy < 0)) {
        attachPenalty += 250;
    }
    return distance + centerDistance + attachPenalty;
}

function guessPreferredSide(reference, candidate, preferredPosition) {
    var refCenterX = Math.round(reference.posX || 0) + logicalWidth(reference) / 2;
    var refCenterY = Math.round(reference.posY || 0) + logicalHeight(reference) / 2;
    var candCenterX = preferredPosition.x + logicalWidth(candidate) / 2;
    var candCenterY = preferredPosition.y + logicalHeight(candidate) / 2;
    var dx = candCenterX - refCenterX;
    var dy = candCenterY - refCenterY;
    if (Math.abs(dx) >= Math.abs(dy)) return dx < 0 ? "left" : "right";
    return dy < 0 ? "top" : "bottom";
}

function findPlacementForOutput(placed, candidate, preferredPosition) {
    if (placed.length === 0) {
        return { x: preferredPosition.x, y: preferredPosition.y };
    }

    var best = null;
    for (var i = 0; i < placed.length; i++) {
        var reference = placed[i];
        var preferredSide = guessPreferredSide(reference, candidate, preferredPosition);
        var sides = [preferredSide, "right", "left", "bottom", "top"];
        var seen = {};
        for (var s = 0; s < sides.length; s++) {
            var side = sides[s];
            if (seen[side]) continue;
            seen[side] = true;
            var placement = candidatePlacement(reference, candidate, side);
            var ghost = {
                posX: placement.x,
                posY: placement.y,
                res: candidate.res,
                scale: candidate.scale
            };
            var collides = false;
            for (var j = 0; j < placed.length; j++) {
                if (outputsOverlap(ghost, placed[j])) {
                    collides = true;
                    break;
                }
            }
            if (collides) continue;
            var score = placementScore(reference, candidate, placement, preferredPosition);
            if (!best || score < best.score) {
                best = { x: placement.x, y: placement.y, score: score };
            }
        }
    }

    if (best) return { x: best.x, y: best.y };

    var fallbackX = 0;
    for (var k = 0; k < placed.length; k++) {
        fallbackX = Math.max(fallbackX, Math.round(placed[k].posX || 0) + logicalWidth(placed[k]));
    }
    return { x: fallbackX, y: 0 };
}

function getDefaultOutputName(outs, savedConfig) {
    for (var i = 0; i < outs.length; i++) {
        if (outs[i].isDefault) return outs[i].name;
    }
    var savedKeys = Object.keys(savedConfig || {});
    for (var j = 0; j < savedKeys.length; j++) {
        var saved = savedConfig[savedKeys[j]];
        if (saved && saved.default) return savedKeys[j];
    }
    return outs.length > 0 ? outs[0].name : "";
}

function autoArrangeOutputs(outs, savedConfig) {
    if (!outs || outs.length <= 1) return outs;

    var arranged = [];
    for (var i = 0; i < outs.length; i++) arranged.push(outs[i]);

    var defaultName = getDefaultOutputName(arranged, savedConfig);
    var anchorIndex = 0;
    for (var a = 0; a < arranged.length; a++) {
        if (arranged[a].name === defaultName) {
            anchorIndex = a;
            break;
        }
    }

    var anchor = arranged[anchorIndex];
    if (!isOutputValid(anchor)) return arranged;

    arranged.splice(anchorIndex, 1);
    arranged.sort(function(left, right) {
        var leftPos = getSavedPosition(left, savedConfig);
        var rightPos = getSavedPosition(right, savedConfig);
        if (leftPos.x !== rightPos.x) return leftPos.x - rightPos.x;
        if (leftPos.y !== rightPos.y) return leftPos.y - rightPos.y;
        return String(left.name).localeCompare(String(right.name));
    });

    anchor.posX = 0;
    anchor.posY = 0;
    var result = [anchor];

    for (var j = 0; j < arranged.length; j++) {
        if (!isOutputValid(arranged[j])) continue;
        var preferred = getSavedPosition(arranged[j], savedConfig);
        var placement = findPlacementForOutput(result, arranged[j], preferred);
        arranged[j].posX = placement.x;
        arranged[j].posY = placement.y;
        result.push(arranged[j]);
    }

    return result;
}

function needsAutoLayout(outs) {
    if (!outs || outs.length <= 1) return false;
    var seen = {};
    for (var i = 0; i < outs.length; i++) {
        var outObj = outs[i];
        if (!isOutputValid(outObj)) return true;
        var key = Math.round(outObj.posX || 0) + ":" + Math.round(outObj.posY || 0);
        if (seen[key]) return true;
        seen[key] = true;
        for (var j = i + 1; j < outs.length; j++) {
            if (outputsOverlap(outObj, outs[j])) return true;
        }
    }
    return false;
}
