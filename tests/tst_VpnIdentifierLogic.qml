import QtQuick
import QtTest
import "../Services/core/VpnIdentifierLogic.js" as VpnIdentifierLogic

TestCase {
    name: "VpnIdentifierLogic"

    readonly property var profiles: [
        { name: "office-vpn", uuid: "123e4567-e89b-42d3-a456-426614174000" },
        { name: "Home WireGuard", uuid: "550e8400-e29b-41d4-a716-446655440000" }
    ]

    function test_acceptsCanonicalUuid() {
        verify(VpnIdentifierLogic.isUuid("123e4567-e89b-42d3-a456-426614174000"));
        verify(VpnIdentifierLogic.isUuid("550E8400-E29B-41D4-A716-446655440000"));
        verify(VpnIdentifierLogic.isUuid("01890f2a-7b3c-7def-8123-456789abcdef"));
    }

    function test_rejectsHyphenatedConnectionName() {
        verify(!VpnIdentifierLogic.isUuid("office-vpn"));
        var result = VpnIdentifierLogic.selector("office-vpn", profiles);
        compare(result.kind, "id");
        compare(result.value, "office-vpn");
    }

    function test_knownProfileUuidUsesUuidSelector() {
        var result = VpnIdentifierLogic.selector(profiles[1].uuid, profiles);
        compare(result.kind, "uuid");
        compare(result.value, profiles[1].uuid);
    }

    function test_unknownNameUsesIdSelector() {
        var result = VpnIdentifierLogic.selector("Custom VPN", profiles);
        compare(result.kind, "id");
        compare(result.value, "Custom VPN");
    }

    function test_trimsInput() {
        var result = VpnIdentifierLogic.selector("  office-vpn  ", profiles);
        compare(result.kind, "id");
        compare(result.value, "office-vpn");
    }
}
