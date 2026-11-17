# Spec Delta

## Purpose

Lets the user find, connect to and keep a reliable link with a BrainBit-family EEG headband (or a simulated one), and shows whether the signal is good enough to measure focus.

## ADDED Requirements

### Requirement: Discover nearby headbands
The app SHALL scan over Bluetooth LE for supported BrainBit-family headbands and list each found device with its name and serial number while the scan runs.

#### Scenario: Headband found during scan
- **WHEN** the user starts a scan and a powered-on supported headband is in range
- **THEN** the device appears in the list with its name and serial number within 10 seconds

#### Scenario: No headband found
- **WHEN** a scan runs for 15 seconds without finding a supported device
- **THEN** the app stops scanning and tells the user no headband was found, with a hint to power the band on and retry

### Requirement: Supported headbands
The app SHALL support the Mindo band (reported by the BrainBit SDK as a "Headband" device), BrainBit and BrainBit 2, and every supported band SHALL provide the same connection, contact-quality, battery and focus features.

#### Scenario: Mindo band
- **WHEN** the user scans with a powered-on Mindo band in range
- **THEN** the Mindo band is listed, connects, and provides EEG data, contact quality and battery level like any other supported band

### Requirement: Bluetooth availability
The app SHALL detect when Bluetooth is off or the app lacks Bluetooth permission and tell the user how to fix it instead of scanning.

#### Scenario: Bluetooth permission denied
- **WHEN** the user starts a scan and the operating system has denied Bluetooth access to the app
- **THEN** the app shows a message explaining that Bluetooth access is required and how to grant it in system settings

### Requirement: Connect to a selected headband
The app SHALL connect to the headband the user selects and report the connection state as disconnected, connecting, connected or reconnecting.

#### Scenario: Successful connection
- **WHEN** the user selects a found headband
- **THEN** the app connects, shows the state as connected and starts receiving EEG data

#### Scenario: Connection fails
- **WHEN** the connection attempt does not succeed within 20 seconds
- **THEN** the app shows the state as disconnected and offers to retry

### Requirement: Remember the last headband
The app SHALL remember the last successfully connected headband and offer to connect to it directly on next launch.

#### Scenario: Quick reconnect on launch
- **WHEN** the app starts and a headband was connected in a previous run
- **THEN** the app offers that headband by name as a one-click connect option

### Requirement: Automatic reconnection
The app SHALL try to reconnect automatically when an established connection drops, for at least 60 seconds, before reporting the headband as disconnected.

#### Scenario: Brief signal loss
- **WHEN** the connection drops and the headband is reachable again within 60 seconds
- **THEN** the app shows reconnecting during the gap and returns to connected without user action

#### Scenario: Headband gone
- **WHEN** the connection drops and the headband is not reachable within 60 seconds
- **THEN** the app shows the state as disconnected and notifies the user

### Requirement: Electrode contact quality
Outside a running session the app SHALL show contact quality for each electrode as good, fair or poor, updated at least once per second while connected.

#### Scenario: Poor contact on one electrode
- **WHEN** one electrode has poor skin contact
- **THEN** that electrode is shown as poor and the app suggests adjusting the band

### Requirement: Signal quality during a session
While a session is running the app SHALL show signal quality for the left and right side of the head as good or poor, derived from the EEG signal itself, updated at least once per second.

#### Scenario: Left side noisy
- **WHEN** the left-side signal is contaminated during a session
- **THEN** the left side is shown as poor and the right side keeps its own status

### Requirement: Battery level
The app SHALL show the headband's battery level while connected and warn the user when it falls to 15% or below.

#### Scenario: Low battery
- **WHEN** the reported battery level reaches 15%
- **THEN** the app shows a low-battery warning

### Requirement: Simulated headband
The app SHALL offer a simulated headband, available in development builds, that behaves like a connected device and produces EEG-like data with controllable focus level, contact quality and disconnections.

#### Scenario: Run without hardware
- **WHEN** a developer selects the simulated headband
- **THEN** the app connects to it and the rest of the app (calibration, focus score, audio feedback, sessions) works as with a real band
