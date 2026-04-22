import QtQuick
import QtTest
import "../Modules/bar/Settings/ApiKeysProviders.js" as Providers

TestCase {
    name: "ApiKeysProviders"

    function test_byId_known() {
        var p = Providers.byId("openai");
        compare(p.id, "openai");
        compare(p.name, "OpenAI");
        verify(p.api_base.length > 0);
    }

    function test_byId_local() {
        var p = Providers.byId("local");
        compare(p.id, "local");
        verify(p.is_local === true);
        compare(p.api_base, "");
    }

    function test_byId_unknown_returnsFirst() {
        var p = Providers.byId("does-not-exist");
        compare(p, Providers.providers[0]);
    }

    function test_byId_null() {
        var p = Providers.byId(null);
        compare(p, Providers.providers[0]);
    }

    function test_providers_haveRequiredKeys() {
        var required = ["id", "name", "description", "api_base", "key_prefix",
                        "key_example", "models", "signup_url", "native"];
        for (var i = 0; i < Providers.providers.length; i++) {
            var p = Providers.providers[i];
            for (var k = 0; k < required.length; k++) {
                verify(p[required[k]] !== undefined,
                    "Provider " + p.id + " is missing required key: " + required[k]);
            }
        }
    }

    function test_providers_idsUnique() {
        var seen = {};
        for (var i = 0; i < Providers.providers.length; i++) {
            var id = Providers.providers[i].id;
            verify(!seen[id], "Duplicate provider id: " + id);
            seen[id] = true;
        }
    }

    function test_providers_containsLocal() {
        var p = Providers.byId("local");
        verify(p.is_local === true);
    }

    function test_providers_modelsAreArrays() {
        for (var i = 0; i < Providers.providers.length; i++) {
            verify(Array.isArray(Providers.providers[i].models),
                "Provider " + Providers.providers[i].id + " models must be an array");
        }
    }

    function test_providers_apiBaseIsHttpsOrEmpty() {
        for (var i = 0; i < Providers.providers.length; i++) {
            var p = Providers.providers[i];
            if (p.api_base.length === 0) continue;
            if (p.api_base.indexOf("localhost") !== -1) continue;
            verify(p.api_base.indexOf("https://") === 0,
                "Provider " + p.id + " api_base should use HTTPS");
        }
    }

    function test_providers_signupUrlIsHttpsOrEmpty() {
        for (var i = 0; i < Providers.providers.length; i++) {
            var p = Providers.providers[i];
            if (p.signup_url.length === 0) continue;
            verify(p.signup_url.indexOf("https://") === 0,
                "Provider " + p.id + " signup_url should use HTTPS");
        }
    }
}
