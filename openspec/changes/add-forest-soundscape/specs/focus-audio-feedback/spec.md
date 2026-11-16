## MODIFIED Requirements

### Requirement: Soundscape selection
The app SHALL let the user choose the feedback soundscape from at least "Birds chirping", "Ocean waves" and "Forest", let them preview it, and remember the choice across launches. The same soundscape is used in both modes.

#### Scenario: Choose ocean
- **WHEN** the user selects "Ocean waves" in settings
- **THEN** feedback uses the ocean soundscape in this and later sessions

#### Scenario: Choose forest
- **WHEN** the user selects "Forest" in settings
- **THEN** feedback uses the forest recording in this and later sessions

#### Scenario: Preview a soundscape
- **WHEN** the user presses preview on a soundscape
- **THEN** a few seconds of it play at the configured volume

#### Scenario: Forest loops seamlessly
- **WHEN** the forest soundscape plays past the end of the recording
- **THEN** it continues from the start without an audible click or gap

## ADDED Requirements

### Requirement: Mono or stereo playback
The app SHALL let the user choose between stereo (default) and mono playback of soundscapes, and remember the choice across launches. In mono, the left and right channels SHALL carry the same signal. The choice applies to the feedback loop and to previews.

#### Scenario: Default is stereo
- **WHEN** the user has never changed the setting
- **THEN** soundscapes play in stereo

#### Scenario: Switch to mono
- **WHEN** the user turns on "Mono sound" in settings
- **THEN** feedback and previews play with identical left and right channels, in this and later sessions

#### Scenario: Switch during a session
- **WHEN** the user toggles "Mono sound" while a session is running
- **THEN** the loop switches to the chosen variant without stopping the session, and keeps playing if it was playing
