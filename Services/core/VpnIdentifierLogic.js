// Pure helpers for choosing an nmcli connection selector.

function normalize(value) {
    return String(value || "").trim();
}

function isUuid(value) {
    var normalized = normalize(value);
    return /^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$/.test(normalized);
}

function selector(identifier, profiles) {
    var normalized = normalize(identifier);
    var knownProfiles = Array.isArray(profiles) ? profiles : [];

    for (var i = 0; i < knownProfiles.length; ++i) {
        var profile = knownProfiles[i] || {};
        if (normalize(profile.uuid) === normalized && normalized.length > 0) {
            return { kind: "uuid", value: normalized };
        }
    }

    for (var j = 0; j < knownProfiles.length; ++j) {
        var namedProfile = knownProfiles[j] || {};
        if (normalize(namedProfile.name) === normalized && normalized.length > 0) {
            return { kind: "id", value: normalized };
        }
    }

    return {
        kind: isUuid(normalized) ? "uuid" : "id",
        value: normalized
    };
}
