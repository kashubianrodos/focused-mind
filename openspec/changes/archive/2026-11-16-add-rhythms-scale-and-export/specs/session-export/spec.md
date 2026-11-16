# Spec Delta

## Purpose

Lets the user take a saved session's data out of the app as CSV files they choose where to save, optionally including the raw EEG signal recorded during the session.

## ADDED Requirements

### Requirement: Export a session to CSV
The app SHALL offer an Export action for each session in history. Export SHALL ask the user for a folder and write the session's timeline there as a CSV file named with the session's date and time, never overwriting an existing file.

#### Scenario: Export a session
- **WHEN** the user exports a 25-minute session from history and picks a folder
- **THEN** a CSV with a header and 1,500 data rows is written into that folder, and the app confirms where it was saved

#### Scenario: Cancel the folder picker
- **WHEN** the user cancels the folder picker
- **THEN** no file is written and nothing changes

#### Scenario: File name taken
- **WHEN** a file with the suggested name already exists in the folder
- **THEN** the export uses a new name instead of overwriting it

#### Scenario: Write failure
- **WHEN** the chosen folder cannot be written
- **THEN** the app shows an error saying the export failed, and the session is unchanged

### Requirement: Timeline CSV contents
The timeline CSV SHALL have a header row and one row per second of the session. It SHALL have columns for: elapsed seconds, wall-clock time, focus score (which is also the scale position), focus state, scale zone, theta, alpha and beta shares, gap, feedback mode, and any drop or recovery mark at that second. Unavailable values SHALL be empty cells.

#### Scenario: Unavailable second
- **WHEN** a second's score was unavailable because of artifacts
- **THEN** that row's score, zone and rhythm cells are empty and its other cells are filled

#### Scenario: Older session
- **WHEN** the user exports a session recorded before rhythms and the scale were saved
- **THEN** the CSV has the same columns, with the rhythm and scale cells empty

### Requirement: Optional raw EEG recording
The app SHALL offer a "Record raw signal" setting, off by default, that states its storage cost. While the setting is on, the app SHALL save the raw O1, O2, T3 and T4 signal of each new session, with a timestamp per sample, on the device alongside the session. Deleting the session SHALL delete its raw recording.

#### Scenario: Recording on
- **WHEN** the setting is on and the user completes a session
- **THEN** the session's raw signal is kept on the device, and the session is marked in history as having a raw recording

#### Scenario: Recording off
- **WHEN** the setting is off
- **THEN** no raw signal is stored for new sessions

#### Scenario: Delete removes the recording
- **WHEN** the user deletes a session that has a raw recording
- **THEN** the raw recording is deleted from the device too

### Requirement: Export the raw signal
When a session has a raw recording, Export SHALL also write it as a second CSV into the same folder, with a header row and one row per sample: seconds since session start, O1, O2, T3 and T4 in microvolts.

#### Scenario: Export with raw signal
- **WHEN** the user exports a session that has a raw recording
- **THEN** two CSV files are written to the chosen folder: the timeline and the raw signal

### Requirement: Export stays local
Export SHALL write only to the folder the user picks and SHALL NOT send data over the network.

#### Scenario: Offline export
- **WHEN** the computer has no network connection
- **THEN** export works normally
