import QtQuick

Item {
    id: vpnManager

    VpnTriggerService {
        id: vpnTriggerService
        onTriggerDetected: addVpnPopup.open()
    }

    AddVpnPopup {
        id: addVpnPopup
        onSuccess: vpnTriggerService.notifyNetworkRefresh()
    }
}
