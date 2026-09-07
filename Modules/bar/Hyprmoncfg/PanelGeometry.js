function fit(width, height, x, y, screenWidth, screenHeight) {
    var margin = Math.min(12, Math.max(0, Math.min(screenWidth, screenHeight) / 4));
    var maxW = Math.max(1, screenWidth - margin * 2);
    var maxH = Math.max(1, screenHeight - margin * 2);
    var w = Math.min(maxW, Math.max(Math.min(980, maxW), width));
    var h = Math.min(maxH, Math.max(Math.min(680, maxH), height));
    return { width: w, height: h,
        x: Math.max(margin, Math.min(screenWidth - w - margin, x)),
        y: Math.max(margin, Math.min(screenHeight - h - margin, y)) };
}
