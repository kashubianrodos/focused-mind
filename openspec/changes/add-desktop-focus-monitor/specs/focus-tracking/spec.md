# Spec Delta

## Purpose

Turns the headband's EEG signal into a live focus score the user and the audio feedback can rely on, calibrated to the wearer at the start of each session.

## ADDED Requirements

### Requirement: Signal check before calibration
The app SHALL start calibration only when every electrode has at least fair contact, and SHALL guide the user to adjust the band until it does.

#### Scenario: Poor contact blocks calibration
- **WHEN** the user starts a session and any electrode has poor contact
- **THEN** the app shows which electrode needs adjusting and waits instead of calibrating

### Requirement: Per-session calibration
The app SHALL run a calibration of at most 60 seconds at the start of each session, asking the user to sit still with eyes open, and SHALL show calibration progress.

#### Scenario: Calibration completes
- **WHEN** the user sits still with good contact during calibration
- **THEN** progress reaches 100% within 60 seconds and live focus tracking begins

#### Scenario: Calibration disturbed
- **WHEN** heavy movement or contact loss prevents calibration from completing within 60 seconds
- **THEN** the app tells the user calibration failed, says why, and offers to restart it

### Requirement: Live focus score
After calibration the app SHALL produce a focus score from 0 to 100, at least once per second, where higher means more focused.

#### Scenario: Score updates while connected
- **WHEN** calibration has completed and the signal is clean
- **THEN** a new focus score between 0 and 100 is available at least every second

### Requirement: Personal baseline
The focus score SHALL be relative to the wearer's own calibration: the level measured during calibration SHALL score the user's baseline (0–100 scale, default 50, adjustable from 20 to 80 in Settings), higher focus SHALL score above it and lower focus below it. A baseline change SHALL apply from the next score update, including during a session.

#### Scenario: Focus at the calibration level
- **WHEN** the wearer's focus is at the level measured during calibration
- **THEN** the focus score is close to the baseline, and above the default threshold

#### Scenario: Raise the baseline mid-session
- **WHEN** the user raises the baseline during a session
- **THEN** the next focus score is higher for the same brain activity, and the new value is kept for later sessions

### Requirement: Score smoothing
The app SHALL smooth the focus score over a short window so that single noisy readings do not swing the displayed value or trigger feedback.

#### Scenario: One outlier reading
- **WHEN** a single raw reading drops sharply between otherwise steady readings
- **THEN** the displayed focus score changes by less than the raw drop and returns toward the steady level

### Requirement: Artifact handling
The app SHALL detect stretches of signal contaminated by movement, blinking bursts or lost contact, mark the score as unavailable during them, and SHALL NOT report them as low focus.

#### Scenario: User moves their head
- **WHEN** the signal is contaminated by artifacts
- **THEN** the focus score is shown as unavailable (not as a low value) and focus-drop feedback is not triggered

#### Scenario: Signal recovers
- **WHEN** the signal is clean again after an artifact
- **THEN** the focus score resumes within 3 seconds without recalibration

### Requirement: Focus state
The app SHALL classify the current smoothed score as focused, neutral or distracted using the user's focus threshold, and SHALL expose this state to the audio feedback and session views.

#### Scenario: Score below threshold
- **WHEN** the smoothed focus score is below the user's threshold
- **THEN** the focus state is distracted

#### Scenario: Score well above threshold
- **WHEN** the smoothed focus score is at least 15 points above the user's threshold
- **THEN** the focus state is focused

### Requirement: Not a medical device
The app SHALL describe the focus score as an estimate for personal feedback and SHALL NOT present it as a medical or diagnostic measurement.

#### Scenario: First launch notice
- **WHEN** the user opens the app for the first time
- **THEN** the app shows a notice that the focus score is an estimate for wellness use only
