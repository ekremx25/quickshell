import QtQuick
import QtTest
import "../Modules/bar/System/MonitorLayoutLogic.js" as Layout

TestCase {
    name: "MonitorLayoutLogic"

    function makeOutput(name, res, hz, posX, posY, scale) {
        return {
            name: name,
            res: res,
            hz: String(hz),
            posX: posX,
            posY: posY,
            scale: String(scale)
        };
    }

    function test_parseResParts_basic() {
        var p = Layout.parseResParts("1920x1080");
        compare(p.width, 1920);
        compare(p.height, 1080);
    }

    function test_parseResParts_4k() {
        var p = Layout.parseResParts("3840x2160");
        compare(p.width, 3840);
        compare(p.height, 2160);
    }

    function test_parseResParts_invalid() {
        var p = Layout.parseResParts("bogus");
        compare(p.width, 0);
        compare(p.height, 0);
    }

    function test_parseResParts_empty() {
        var p = Layout.parseResParts("");
        compare(p.width, 0);
        compare(p.height, 0);
    }

    function test_parseResParts_null() {
        var p = Layout.parseResParts(null);
        compare(p.width, 0);
        compare(p.height, 0);
    }

    function test_isOutputValid_good() {
        verify(Layout.isOutputValid(makeOutput("DP-1", "1920x1080", 60, 0, 0, 1)));
    }

    function test_isOutputValid_zeroHz() {
        verify(!Layout.isOutputValid(makeOutput("DP-1", "1920x1080", 0, 0, 0, 1)));
    }

    function test_isOutputValid_zeroRes() {
        verify(!Layout.isOutputValid(makeOutput("DP-1", "0x0", 60, 0, 0, 1)));
    }

    function test_isOutputValid_null() {
        verify(!Layout.isOutputValid(null));
    }

    function test_logicalWidth_noScale() {
        var o = makeOutput("DP-1", "1920x1080", 60, 0, 0, 1);
        compare(Layout.logicalWidth(o), 1920);
        compare(Layout.logicalHeight(o), 1080);
    }

    function test_logicalWidth_scaled() {
        var o = makeOutput("DP-1", "3840x2160", 60, 0, 0, 2);
        compare(Layout.logicalWidth(o), 1920);
        compare(Layout.logicalHeight(o), 1080);
    }

    function test_logicalWidth_fractionalScale() {
        var o = makeOutput("DP-1", "3840x2160", 60, 0, 0, 1.25);
        compare(Layout.logicalWidth(o), 3072);
        compare(Layout.logicalHeight(o), 1728);
    }

    function test_logicalWidth_invalidScale() {
        var o = makeOutput("DP-1", "1920x1080", 60, 0, 0, 0);
        compare(Layout.logicalWidth(o), 1920);
    }

    function test_overlap_sideBySide() {
        var a = makeOutput("A", "1920x1080", 60, 0, 0, 1);
        var b = makeOutput("B", "1920x1080", 60, 1920, 0, 1);
        verify(!Layout.outputsOverlap(a, b));
    }

    function test_overlap_overlapping() {
        var a = makeOutput("A", "1920x1080", 60, 0, 0, 1);
        var b = makeOutput("B", "1920x1080", 60, 0, 0, 1);
        verify(Layout.outputsOverlap(a, b));
    }

    function test_overlap_partial() {
        var a = makeOutput("A", "1920x1080", 60, 0, 0, 1);
        var b = makeOutput("B", "1920x1080", 60, 1000, 0, 1);
        verify(Layout.outputsOverlap(a, b));
    }

    function test_overlap_touching_zero() {
        var a = makeOutput("A", "1920x1080", 60, 0, 0, 1);
        var b = makeOutput("B", "1920x1080", 60, 1920, 0, 1);
        compare(Layout.horizontalOverlapAmount(a, b), 0);
    }

    function test_needsAutoLayout_singleOutput() {
        var outs = [makeOutput("A", "1920x1080", 60, 0, 0, 1)];
        verify(!Layout.needsAutoLayout(outs));
    }

    function test_needsAutoLayout_clean() {
        var outs = [
            makeOutput("A", "1920x1080", 60, 0, 0, 1),
            makeOutput("B", "1920x1080", 60, 1920, 0, 1)
        ];
        verify(!Layout.needsAutoLayout(outs));
    }

    function test_needsAutoLayout_overlap() {
        var outs = [
            makeOutput("A", "1920x1080", 60, 0, 0, 1),
            makeOutput("B", "1920x1080", 60, 100, 0, 1)
        ];
        verify(Layout.needsAutoLayout(outs));
    }

    function test_needsAutoLayout_invalidOutput() {
        var outs = [
            makeOutput("A", "1920x1080", 60, 0, 0, 1),
            makeOutput("B", "0x0", 60, 1920, 0, 1)
        ];
        verify(Layout.needsAutoLayout(outs));
    }

    function test_autoArrange_anchorAtOrigin() {
        var outs = [
            makeOutput("A", "1920x1080", 60, 500, 500, 1),
            makeOutput("B", "1920x1080", 60, 1000, 500, 1)
        ];
        outs[0].isDefault = true;
        var arranged = Layout.autoArrangeOutputs(outs, {});
        var a = arranged.find(function(o) { return o.name === "A"; });
        compare(a.posX, 0);
        compare(a.posY, 0);
    }

    function test_autoArrange_noOverlap() {
        var outs = [
            makeOutput("A", "1920x1080", 60, 0, 0, 1),
            makeOutput("B", "1920x1080", 60, 0, 0, 1)
        ];
        outs[0].isDefault = true;
        var arranged = Layout.autoArrangeOutputs(outs, {});
        verify(!Layout.outputsOverlap(arranged[0], arranged[1]));
    }
}
