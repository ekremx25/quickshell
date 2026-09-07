const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const scope = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, "../Modules/bar/Hyprmoncfg/PanelGeometry.js"), "utf8"), scope);
for (const [width, height] of [[3840,2160], [2560,1440], [1280,720], [960,540], [640,360]]) {
    for (const [w,h,x,y] of [[1320,900,0,0], [4000,3000,-200,-100], [100,100,5000,5000]]) {
        const r = scope.fit(w,h,x,y,width,height);
        assert.ok(r.width > 0 && r.height > 0);
        assert.ok(r.x >= 0 && r.y >= 0);
        assert.ok(r.x + r.width <= width && r.y + r.height <= height);
        assert.equal(JSON.stringify(scope.fit(r.width,r.height,r.x,r.y,width,height)), JSON.stringify(r), "stable, no resize feedback");
    }
}
console.log("Panel bounds at multiple logical screen sizes passed");
