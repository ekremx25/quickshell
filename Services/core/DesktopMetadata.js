.pragma library

// desktop_icons.sh emits up to three adjacent JSON objects, not a JSON array.
function parse(raw) {
    var documents = [];
    var start = -1;
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var i = 0; i < raw.length; i++) {
        var c = raw[i];
        if (start < 0) {
            if (/\s/.test(c)) continue;
            if (c !== "{" || documents.length === 3) throw new Error("Invalid desktop metadata");
            start = i;
        }
        if (quoted) {
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === '"') quoted = false;
        } else if (c === '"') quoted = true;
        else if (c === "{") depth++;
        else if (c === "}") {
            depth--;
            if (depth === 0) {
                documents.push(JSON.parse(raw.substring(start, i + 1)));
                start = -1;
            }
        }
    }
    if (start >= 0 || documents.length === 0) throw new Error("Incomplete desktop metadata");
    return { icons: documents[0], commands: documents[1] || {}, entries: documents[2] || {} };
}
