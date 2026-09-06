const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../Services/core/WallpaperSpectrum.js'), 'utf8').replace(/^\.pragma library\s*$/m, '');
const ctx = vm.createContext({});
vm.runInContext(source, ctx);
const green = ['#2E6A32', '#F1E2CB', '#173017', '#71A8CA', '#A35D1A', '#F6B14E'];
const blue = ['#143C86', '#60BCE7', '#DAF4FF', '#E3AD4C'];
for (const bg of ['#10140f', '#fff8f7']) {
  const a = ctx.accents(green, bg, ['#ff0000']);
  const b = ctx.accents(blue, bg, ['#ff0000']);
  assert.equal(a.length, 6);
  assert.notEqual(a[0], b[0], 'new image must change the dominant module accent');
  for (const color of a) assert.ok(ctx.contrast(ctx.rgb(color), ctx.rgb(bg)) >= 4.5, `${color} on ${bg}`);
  const channels = ctx.rgb(a[0]);
  assert.ok(channels[1] > channels[0] && channels[1] > channels[2], 'green wallpaper remains green');
}
const mono = ctx.accents(['#333333'], '#101010', ['#ff0000']);
assert.equal(new Set(mono).size, 1, 'uniform wallpaper must not gain unrelated accent hues');
assert.equal(ctx.accents([], '#101010', ['#123456'])[0], '#123456');
console.log('Wallpaper spectrum color and contrast tests passed');

for (const light of [false, true]) {
  const surface = ctx.surfaces(green, light);
  assert.ok(ctx.contrast(ctx.rgb(surface.text), ctx.rgb(surface.background)) >= 4.5);
  assert.ok(ctx.contrast(ctx.rgb(surface.subtext), ctx.rgb(surface.panel)) >= 4.5);
  assert.ok(ctx.rgb(surface.background)[1] > ctx.rgb(surface.background)[0], 'surfaces follow dominant green too');
  assert.notEqual(surface.background, ctx.surfaces(blue, light).background);
}

// Muted olive wallpaper must not become a washed-out gray-green chip.
for (const sample of ['#6B744E', '#D4B456', '#3C817D', '#333E4B', '#143C86']) {
  for (const bg of ['#10140f', '#fff8f7']) {
    const output = ctx.rgb(ctx.readable(sample, bg));
    const ink = bg === '#10140f' ? ctx.rgb('#080a0d') : [1, 1, 1];
    assert.ok(ctx.contrast(output, ink) >= 7.0, 'small icon contrast: ' + sample);
    assert.ok(ctx.hsl(output)[1] >= 0.55, 'preserve chromatic saturation: ' + sample);
    const originalHue = ctx.hsl(ctx.rgb(sample))[0], hue = ctx.hsl(output)[0];
    const difference = Math.abs(originalHue - hue);
    assert.ok(Math.min(difference, 360 - difference) < 2, 'keep wallpaper hue');
  }
}
assert.equal(ctx.hsl(ctx.rgb(ctx.readable('#555555', '#101010')))[1], 0, 'gray remains gray');
console.log('Vivid accent and small-icon contrast tests passed');
