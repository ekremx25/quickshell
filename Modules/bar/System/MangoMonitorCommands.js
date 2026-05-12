.pragma library

// Builds direct-argv steps for applying one MangoWC output configuration.
// Two sequential sed invocations: delete old rule, insert new rule.
// configPath must be the fully-expanded path (no ~ or $HOME).
function buildOutputSteps(monName, monRes, monHz, monPosX, monPosY, monScale, sedEscape, configPath) {
    var resParts   = monRes.split("x");
    var monRefresh = Math.round(parseFloat(monHz));
    var ruleStr    = "monitorrule=name:" + monName
                   + ",width:"   + resParts[0]
                   + ",height:"  + resParts[1]
                   + ",refresh:" + monRefresh
                   + ",x:" + monPosX
                   + ",y:" + monPosY
                   + ",scale:" + monScale;
    return [
        { argv: ["sed", "-i", "/^monitorrule=name:" + sedEscape(monName) + "/d", configPath] },
        { argv: ["sed", "-i", "/^# Monitor Rules$/a " + ruleStr, configPath] }
    ];
}
