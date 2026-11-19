# Spec Delta

## MODIFIED Requirements

### Requirement: Discover nearby headbands
The app SHALL scan over Bluetooth LE for supported BrainBit-family headbands and list each found device with its name and serial number while the scan runs. Real headbands SHALL be listed before the simulated headband.

#### Scenario: Headband found during scan
- **WHEN** the user starts a scan and a powered-on supported headband is in range
- **THEN** the device appears in the list with its name and serial number within 10 seconds, above the simulated headband

#### Scenario: No headband found
- **WHEN** a scan runs for 15 seconds without finding a supported real device
- **THEN** the app stops scanning and tells the user no headband was found, with a hint to power the band on and retry, and points to the simulated headband to try the app without one

## ADDED Requirements

### Requirement: Always-available simulated headband
The app SHALL offer a simulated headband that behaves like a connected device and produces EEG-like data with controllable focus level, contact quality and disconnections, and every build (including App Store, TestFlight and release APK) SHALL list it on every scan without any setting, also when Bluetooth is off or not allowed. Its focus level SHALL hold steady for the first minute and then drift up and down.

#### Scenario: Run without hardware
- **WHEN** a user without a headband scans and selects the simulated headband
- **THEN** the app connects to it and the rest of the app (calibration, focus score, audio feedback, sessions) works as with a real band

#### Scenario: Release build lists the simulator
- **WHEN** the user scans in a release build
- **THEN** the simulated headband is listed, without any setting having been changed

#### Scenario: Simulator without Bluetooth
- **WHEN** Bluetooth is off or the app is not allowed to use it, and the user scans
- **THEN** the app shows how to enable Bluetooth access, and the simulated headband is still listed and connects

## REMOVED Requirements

### Requirement: Simulated headband
**Reason**: Replaced by "Always-available simulated headband". The simulator is no longer gated behind a Test mode setting, so the Test mode scenarios no longer apply.
**Migration**: None for users. The Settings › Data › Test mode switch is removed; the stored `test_mode` preference is ignored.
