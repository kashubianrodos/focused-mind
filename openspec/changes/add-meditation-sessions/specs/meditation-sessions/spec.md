# Spec Delta

## Purpose

Lets the user run a meditation session instead of a focus session. A meditation session uses the same headband measurement and session features, but its goal, display and sound reward the relaxed, calm end of the relaxation–concentration scale.

## ADDED Requirements

### Requirement: Choose the session type before starting
The session start screen SHALL offer a choice between a Focus session and a Meditation session, next to the session length. The choice SHALL default to the type used for the previous session, or Focus if there is none. The chosen type SHALL apply to the whole session and SHALL NOT change once the session has started.

#### Scenario: First use
- **WHEN** the user opens the start screen and has never started a session
- **THEN** Focus is selected

#### Scenario: Remember the last type
- **WHEN** the user starts a meditation session, ends it, and later returns to the start screen (also after restarting the app)
- **THEN** Meditation is selected

#### Scenario: Focus session unchanged
- **WHEN** the user starts a Focus session
- **THEN** the score, states, gauge, graph, sound, drops and summary behave exactly as they did before session types existed

### Requirement: Session type shown during and after a session
While a session is in progress, every session screen SHALL show the session type at the top: signal check, calibration, the live session, the pause after a disconnection, and the end-of-session summary. It SHALL read "Focus session" or "Meditation session".

#### Scenario: Meditation in progress
- **WHEN** a meditation session is running
- **THEN** the top of the live view reads "Meditation session"

#### Scenario: Calibrating a focus session
- **WHEN** a focus session is calibrating
- **THEN** the top of the calibration view reads "Focus session"

### Requirement: Calm score and states in meditation
In a meditation session the live view SHALL show a calm score equal to 100 minus the focus score, so a higher number means calmer. The state SHALL be Calm while the scale is in Relaxation or Deep relaxation, and Restless while it is in Concentration or Deep concentration. When the focus score is unavailable, the calm score and state SHALL be shown as unavailable, as in a focus session.

#### Scenario: Relaxed wearer
- **WHEN** the focus score is 22 and the scale is in Relaxation
- **THEN** the live view shows 78 and the state Calm

#### Scenario: Concentrating wearer
- **WHEN** the focus score is 82 and the scale is in Concentration
- **THEN** the live view shows 18 and the state Restless

#### Scenario: Unavailable signal
- **WHEN** the focus score is unavailable because of artifacts
- **THEN** the live view shows no calm score and says the reading is unavailable

### Requirement: Calm graph in meditation
In a meditation session the live graph, and the summary and history graphs of that session, SHALL plot the calm score over time. They SHALL keep the same time range, gaps and marks as in a focus session.

#### Scenario: Graph follows the calm score
- **WHEN** the wearer moves from Concentration into Deep relaxation during a meditation session
- **THEN** the graph line rises

### Requirement: Mirrored scale gauge in meditation
In a meditation session the scale gauge SHALL show the four zones in reverse order, left to right: Deep concentration, Concentration, Relaxation, Deep relaxation. The needle SHALL move right as the wearer becomes calmer. The zones, their colours, their boundaries and the current zone name SHALL stay the same as in a focus session at the same moment.

#### Scenario: Calm wearer on the mirrored gauge
- **WHEN** the scale is in Deep relaxation during a meditation session
- **THEN** the needle is in the rightmost zone and the gauge names Deep relaxation

#### Scenario: Same zone in both session types
- **WHEN** the same focus score occurs in a focus session and in a meditation session with the same baseline
- **THEN** both gauges name the same zone

### Requirement: Meditation sound feedback
In a meditation session the soundscape SHALL play continuously while the wearer is in Relaxation or Deep relaxation. It SHALL get louder the deeper they go into Relaxation, reaching the set volume in Deep relaxation. It SHALL go silent after the trigger delay in Concentration or Deep concentration. The Alert/Continuous feedback setting SHALL NOT apply.

#### Scenario: Deep relaxation
- **WHEN** the scale stays in Deep relaxation during a meditation session
- **THEN** the soundscape plays at the set volume

#### Scenario: Becoming restless
- **WHEN** the scale stays in Concentration or Deep concentration for longer than the trigger delay
- **THEN** the soundscape fades to silence

#### Scenario: Calming down again
- **WHEN** the soundscape is silent because the wearer was restless, and the scale then stays in Relaxation or Deep relaxation for the recovery time
- **THEN** the soundscape fades back in

#### Scenario: Alert mode selected in settings
- **WHEN** the feedback mode setting is Alert and the user starts a meditation session
- **THEN** the soundscape plays while the wearer is calm, not when they become restless

#### Scenario: Mute and signal loss
- **WHEN** the user mutes, or the score has been unavailable for longer than the silence limit
- **THEN** the soundscape is silent, as in a focus session

### Requirement: Restless episodes in meditation
In a meditation session the app SHALL track restless episodes in place of focus drops. An episode starts after the trigger delay in Concentration or Deep concentration. It ends after the recovery time back in Relaxation or Deep relaxation. The summary SHALL report the number of restless episodes, the time spent calm and the longest calm stretch, in place of drops, time focused and longest focus.

#### Scenario: Meditation summary
- **WHEN** a meditation session ends after one restless episode
- **THEN** the summary shows 1 restless episode, the time calm and the longest calm stretch, together with the time in each zone and the rhythm shares, which are shown as in a focus session

### Requirement: Session type in history and export
Each saved session SHALL record its type. History SHALL show the type of each session, and its detail view SHALL use the meditation wording and the calm score for meditation sessions. Sessions saved before session types existed SHALL load as focus sessions. The timeline CSV export SHALL include a session type column, with the value `focus` or `meditation` on every row. The focus score column SHALL keep the raw focus score for both types.

#### Scenario: History entry
- **WHEN** the user opens history after a meditation session
- **THEN** that session is marked as a meditation session

#### Scenario: Older session
- **WHEN** the user opens a session saved before session types existed
- **THEN** it is shown and exported as a focus session

#### Scenario: Export a meditation session
- **WHEN** the user exports a meditation session
- **THEN** every row of the CSV has `meditation` in the session type column and the raw focus score in the focus score column
