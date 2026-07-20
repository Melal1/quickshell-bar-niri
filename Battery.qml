pragma Singleton

import Quickshell
import Quickshell.Services.UPower

/**
* Battery singleton. Wraps Quickshell's UPower service and exposes the basic
* things about the laptop's primary battery. Source of truth is
* `UPower.displayDevice` (the system aggregate) gated by `ready` and
* `isLaptopBattery` so on desktops without a battery every property falls
* back to a safe neutral value.
*
* UPower is push-based via DBus property updates, so all `readonly` properties
* below update automatically as the underlying device changes — no polling,
* no `FileView`, no timers.
*/
Singleton {
  id: root

  readonly property var device: UPower.displayDevice
  readonly property bool available: device && device.ready && device.isLaptopBattery

  readonly property real level: available ? device.percentage : 0

  readonly property bool charging:
  available && device.state === UPowerDeviceState.Charging

  readonly property int state: available ? device.state : -1
  readonly property string state_name:
  available ? UPowerDeviceState.toString(device.state) : "Unknown"

  readonly property bool on_battery: UPower.onBattery

  readonly property real time_to_empty: available ? device.timeToEmpty : 0
  readonly property real time_to_full:  available ? device.timeToFull  : 0
  // readonly property real change_rate:   available ? device.changeRate  : 0
  //
  // readonly property real energy:          available ? device.energy          : 0
  // readonly property real energy_capacity: available ? device.energyCapacity  : 0
  //
  // readonly property real health_percentage:
  //   available ? device.healthPercentage : 0
  // readonly property bool health_supported:
  //   available ? device.healthSupported : false
  //
  // readonly property string model:     available ? device.model    : ""
  // readonly property string icon_name: available ? device.iconName : ""
}
