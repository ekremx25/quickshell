.pragma library

// Single source of truth for every colour scheme exposed by Quickshell.
// `engineType` is the scheme passed to matugen. `presentation` selects an
// optional Quickshell-specific distribution of the generated colour roles.
var _schemes = [
    { id: "scheme-wallpaper-spectrum", label: "Wallpaper Spectrum", engineType: "scheme-fidelity", presentation: "wallpaper-spectrum", authored: false, wallpaperReactive: true },
    { id: "scheme-tonal-spot",        label: "Tonal Spot",         engineType: "scheme-tonal-spot", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-neutral",           label: "Neutral",            engineType: "scheme-neutral", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-fidelity",          label: "Fidelity",           engineType: "scheme-fidelity", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-vibrant",           label: "Vibrant",            engineType: "scheme-vibrant", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-expressive",        label: "Expressive",         engineType: "scheme-expressive", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-fruit-salad",       label: "Fruit Salad",        engineType: "scheme-fruit-salad", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-rainbow",           label: "Rainbow",            engineType: "scheme-rainbow", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-monochrome",        label: "Monochrome",         engineType: "scheme-monochrome", presentation: "monochrome", authored: false, wallpaperReactive: true },
    { id: "scheme-content",           label: "Content",            engineType: "scheme-content", presentation: "material", authored: false, wallpaperReactive: true },
    { id: "scheme-catppuccin",        label: "Catppuccin",         engineType: "", presentation: "catppuccin", authored: true, wallpaperReactive: false },
    { id: "scheme-kanagawa",          label: "Kanagawa",           engineType: "", presentation: "kanagawa", authored: true, wallpaperReactive: false },
    { id: "scheme-tokyo-night",       label: "Tokyo Night",        engineType: "", presentation: "tokyo-night", authored: true, wallpaperReactive: false }
];

function descriptor(id) {
    for (var i = 0; i < _schemes.length; ++i) {
        if (_schemes[i].id === id) return _schemes[i];
    }
    return null;
}

function ids() {
    var result = [];
    for (var i = 0; i < _schemes.length; ++i) result.push(_schemes[i].id);
    return result;
}

function isSupported(id) { return descriptor(id) !== null; }
function isAuthored(id) {
    var item = descriptor(id);
    return item ? item.authored : false;
}
function isWallpaperReactive(id) {
    var item = descriptor(id);
    return item ? item.wallpaperReactive : false;
}
function engineType(id) {
    var item = descriptor(id);
    return item ? item.engineType : "";
}
function presentation(id) {
    var item = descriptor(id);
    return item ? item.presentation : "material";
}
function label(id) {
    var item = descriptor(id);
    return item ? item.label : id.replace("scheme-", "");
}
