# Spec Delta

## Purpose

Frames focus tracking as work sessions the user starts and ends, shows focus live while they work, and summarizes and keeps each session so they can see how their focus changes over time.

## ADDED Requirements

### Requirement: Start a session
The app SHALL let the user start a focus session only while a headband is connected, optionally with a planned duration (for example 25, 50 or 90 minutes), and SHALL begin with the signal check and calibration.

#### Scenario: Start with a planned duration
- **WHEN** the user picks 50 minutes and starts a session with a connected headband
- **THEN** the app runs the signal check and calibration, then starts a 50-minute session timer

#### Scenario: No headband connected
- **WHEN** no headband is connected
- **THEN** the start action is disabled and the app points the user to connect a headband

### Requirement: End a session
The app SHALL end a session when the user stops it or when a planned duration elapses, and SHALL stop any playing feedback when the session ends.

#### Scenario: Planned duration elapses
- **WHEN** the session timer reaches the planned duration
- **THEN** the app plays a short end chime, ends the session and shows its summary

### Requirement: Pause during disconnection
The app SHALL pause session timing while the headband is disconnected or reconnecting, and SHALL resume the session when the connection returns without recalibrating if the gap was under 60 seconds.

#### Scenario: Short disconnection
- **WHEN** the headband reconnects 20 seconds after dropping mid-session
- **THEN** the session resumes, the gap is marked on the graph and is excluded from focus statistics

### Requirement: Live session view
During a session the app SHALL show the current focus score and state, a graph of the score since the session started, elapsed (and remaining, if planned) time, connection state, signal quality, the feedback mode, and whether feedback is playing or muted.

#### Scenario: Watching focus live
- **WHEN** a session is running after calibration
- **THEN** the graph gains a new point at least every second and the current state is shown as focused, neutral or distracted

### Requirement: Compact always-visible indicator
While a session runs, the app SHALL show the current focus state in the macOS menu bar so the user can follow it while the main window is hidden.

#### Scenario: Main window hidden
- **WHEN** the user hides the main window during a session
- **THEN** the menu bar shows the current focus state and score, and lets the user open the window, mute feedback or end the session

### Requirement: Session summary
When a session ends, the app SHALL show a summary with total duration, average focus score, time spent in each focus state, number of focus drops, number of recoveries, longest focused stretch and the session's focus graph.

#### Scenario: Summary after a session
- **WHEN** a session with two focus drops and two recoveries ends
- **THEN** the summary shows 2 drops and 2 recoveries along with the other statistics and the graph

### Requirement: Session history
The app SHALL save each completed session's summary and focus timeline on the device, list past sessions newest first, and let the user open or delete any of them.

#### Scenario: Review a past session
- **WHEN** the user opens a session from the history list
- **THEN** the app shows that session's summary and graph as they were when it ended

#### Scenario: Delete a session
- **WHEN** the user deletes a session from history and confirms
- **THEN** the session is removed from the list and from the device

### Requirement: Data stays on the device
The app SHALL store sessions and settings only on the user's device and SHALL NOT send EEG data, scores or sessions over the network.

#### Scenario: Offline use
- **WHEN** the computer has no network connection
- **THEN** connecting, sessions, feedback and history all work normally
