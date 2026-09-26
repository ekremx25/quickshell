.pragma library

// NetworkManager's terse mode escapes field separators and literal
// backslashes. Keep unknown escapes intact so parsing never drops data.
function splitLine(line) {
    var text = String(line || "");
    var fields = [];
    var field = "";
    var escaped = false;

    for (var i = 0; i < text.length; i++) {
        var ch = text[i];
        if (escaped) {
            if (ch === ":" || ch === "\\") field += ch;
            else field += "\\" + ch;
            escaped = false;
        } else if (ch === "\\") {
            escaped = true;
        } else if (ch === ":") {
            fields.push(field);
            field = "";
        } else {
            field += ch;
        }
    }

    if (escaped) field += "\\";
    fields.push(field);
    return fields;
}

function parseLines(text) {
    var lines = String(text || "").split("\n");
    var records = [];
    for (var i = 0; i < lines.length; i++) {
        if (lines[i].length === 0) continue;
        records.push(splitLine(lines[i]));
    }
    return records;
}
