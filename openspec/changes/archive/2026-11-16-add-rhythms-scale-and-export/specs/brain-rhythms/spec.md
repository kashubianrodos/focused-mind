# Spec Delta

## Purpose

Shows how the EEG is split between the theta, alpha and beta rhythms, live and over the session, so the user can see what their brain is doing behind the focus score.

## ADDED Requirements

### Requirement: Rhythm shares
After calibration, the app SHALL estimate at least once per second the share of the theta, alpha and beta rhythms in the signal, as percentages that add up to 100. Rhythm shares SHALL be unavailable during artifacts or disconnection, and SHALL NOT be shown as zero.

#### Scenario: Clean signal
- **WHEN** a session is running with a clean signal
- **THEN** a new set of theta, alpha and beta shares adding up to 100% is available at least every second

#### Scenario: Artifacts
- **WHEN** the signal is contaminated by artifacts
- **THEN** the rhythm shares are marked unavailable for those seconds

### Requirement: Live rhythm pie
During a running session, the live session view SHALL show a pie of the current theta, alpha and beta shares, each in its own colour with its percentage and a legend.

#### Scenario: Pie updates
- **WHEN** the rhythm shares change during a session
- **THEN** the pie's segments change to the new shares within one second

#### Scenario: Pie while unavailable
- **WHEN** the rhythm shares are unavailable
- **THEN** the pie shows that the reading is unavailable instead of stale segments

### Requirement: Rhythms over time
During a running session, the live session view SHALL show a stacked chart of the theta, alpha and beta shares over the session, sharing the time axis of the focus graph. Gaps and unavailable seconds SHALL appear as breaks.

#### Scenario: Stacked chart grows
- **WHEN** a session runs for two minutes with a clean signal
- **THEN** the stacked chart covers those two minutes, and at every second its three layers add up to 100%

### Requirement: Rhythms in the session record
The app SHALL save the per-second rhythm shares with each session. The summary and the history detail SHALL show the stacked rhythm chart and the session's average theta, alpha and beta shares. Sessions saved before rhythms were recorded SHALL still open, without rhythm views.

#### Scenario: Review rhythms later
- **WHEN** the user opens a past session from history
- **THEN** the app shows its stacked rhythm chart and average rhythm shares as recorded

#### Scenario: Older session
- **WHEN** the user opens a session recorded before rhythms were saved
- **THEN** the session's summary and focus graph open normally, and the rhythm views are omitted
