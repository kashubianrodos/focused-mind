# Spec Delta

## Purpose

Helps the user stay on task with a chosen soundscape. In alert mode it plays when focus drops and fades away once they refocus. In continuous mode it plays while they are focused and goes quiet when focus is lost.

## ADDED Requirements

### Requirement: Feedback mode
The app SHALL offer two feedback modes, "Alert" (default) and "Continuous". It SHALL remember the chosen mode across launches and apply a change immediately, including during a session.

#### Scenario: Default mode
- **WHEN** the user starts their first session without changing settings
- **THEN** feedback runs in alert mode

#### Scenario: Switch mode mid-session
- **WHEN** the user switches from alert to continuous during a session
- **THEN** from the next score update the soundscape follows continuous-mode rules, with volume changes faded over about 2 seconds

### Requirement: Soundscape selection
The app SHALL let the user choose the feedback soundscape from at least "Birds chirping" and "Ocean waves", let them preview it, and remember the choice across launches. The same soundscape is used in both modes.

#### Scenario: Choose ocean
- **WHEN** the user selects "Ocean waves" in settings
- **THEN** feedback uses the ocean soundscape in this and later sessions

#### Scenario: Preview a soundscape
- **WHEN** the user presses preview on a soundscape
- **THEN** a few seconds of it play at the configured volume

### Requirement: Focus drops and recoveries
In both modes, a focus drop SHALL be recorded when the focus state stays distracted for the trigger delay (default 5 seconds, adjustable 3–30 seconds). A recovery SHALL be recorded when, after a drop, the state stays focused for 3 seconds.

#### Scenario: Drop then recovery
- **WHEN** the state is distracted for the trigger delay and later focused for 3 seconds
- **THEN** one drop and one recovery are recorded for the session

#### Scenario: Momentary dip
- **WHEN** the focus state is distracted for less than the trigger delay and then leaves distracted
- **THEN** no drop is recorded and the sound does not change because of it

### Requirement: Alert mode playback
In alert mode the app SHALL keep the soundscape silent while no drop is active. It SHALL fade the soundscape in over about 2 seconds when a drop is recorded, and fade it out over about 2 seconds when the recovery is recorded.

#### Scenario: Sustained drop
- **WHEN** a drop is recorded in alert mode
- **THEN** the soundscape fades in over about 2 seconds

#### Scenario: User refocuses
- **WHEN** the soundscape is playing in alert mode and a recovery is recorded
- **THEN** the soundscape fades out over about 2 seconds

#### Scenario: Neutral state does not stop feedback
- **WHEN** the soundscape is playing in alert mode and the focus state moves from distracted to neutral
- **THEN** the soundscape keeps playing

### Requirement: Alert intensity follows focus deficit
In alert mode, while the soundscape plays, its loudness SHALL increase as the focus score falls further below the threshold, never exceeding the user's configured volume.

#### Scenario: Deeper drop
- **WHEN** the focus score falls from just below the threshold to far below it while the alert soundscape plays
- **THEN** the soundscape gets louder, up to the configured volume

### Requirement: Continuous mode playback
In continuous mode the app SHALL play the soundscape while no drop is active. It SHALL fade the soundscape to silence over about 2 seconds when a drop is recorded, and fade it back in over about 2 seconds when the recovery is recorded.

#### Scenario: Focused work
- **WHEN** a session in continuous mode is running after calibration and the user is focused or neutral
- **THEN** the soundscape plays

#### Scenario: Focus lost
- **WHEN** a drop is recorded in continuous mode
- **THEN** the soundscape fades to silence over about 2 seconds

#### Scenario: Focus regained
- **WHEN** the soundscape is silent after a drop in continuous mode and a recovery is recorded
- **THEN** the soundscape fades back in over about 2 seconds

### Requirement: Continuous intensity follows focus
In continuous mode, while the soundscape plays, its loudness SHALL rise with the focus score and reach the user's configured volume at high focus, never exceeding it.

#### Scenario: Deeper focus
- **WHEN** the focus score rises from just above the threshold to near 100 in continuous mode
- **THEN** the soundscape gets louder, up to the configured volume

### Requirement: No feedback changes without a valid score
In both modes the app SHALL NOT record drops or recoveries while the focus score is unavailable. If the score stays unavailable for more than 10 seconds, it SHALL fade any playing soundscape to silence until a valid score returns.

#### Scenario: Band removed
- **WHEN** the score becomes unavailable because the headband lost contact
- **THEN** no drop is recorded, and any playing soundscape fades to silence after 10 seconds

#### Scenario: Signal returns in continuous mode
- **WHEN** a valid score returns after a silent unavailable period in continuous mode and no drop is active
- **THEN** the soundscape fades back in

### Requirement: Feedback settings
The app SHALL let the user set the feedback mode, volume, focus threshold (0–100, default 40) and trigger delay. It SHALL apply changes immediately, including during a session.

#### Scenario: Change threshold mid-session
- **WHEN** the user raises the focus threshold during a session
- **THEN** the new threshold is used for the focus state and feedback from the next score update

### Requirement: Mute feedback
The app SHALL let the user mute feedback for the rest of the session with one action, in either mode, without stopping focus tracking or the recording of drops and recoveries.

#### Scenario: Mute during a call
- **WHEN** the user mutes feedback during a session
- **THEN** no soundscape plays for the rest of that session, while the focus score keeps updating and drops and recoveries are still recorded
