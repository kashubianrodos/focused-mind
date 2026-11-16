# Spec Delta

## Purpose

Shows where the wearer is between deep relaxation and deep concentration, relative to their own calibrated level, on a four-zone scale updated in real time during a session.

## ADDED Requirements

### Requirement: Four-zone relaxation–concentration scale
The app SHALL place the wearer's current state on a continuous scale with four zones, from low to high: Deep relaxation, Relaxation, Concentration and Deep concentration. The position SHALL come from the same calibration-relative measurement as the focus score. The wearer's calibrated level SHALL sit on the boundary between Relaxation and Concentration, and the user's baseline setting SHALL move the boundary as it moves the focus score.

#### Scenario: At the calibrated level
- **WHEN** the wearer's brain activity matches the level measured during calibration
- **THEN** the scale points at the boundary between Relaxation and Concentration

#### Scenario: Much more focused than at calibration
- **WHEN** the wearer becomes much more focused than at calibration
- **THEN** the scale moves into Deep concentration

#### Scenario: Much less focused than at calibration
- **WHEN** the wearer becomes much more relaxed than at calibration
- **THEN** the scale moves into Deep relaxation

#### Scenario: Zones agree with the focus score
- **WHEN** the focus score rises
- **THEN** the scale position never moves towards relaxation at the same update

### Requirement: Real-time scale gauge
During a running session, the live session view SHALL show the scale as a gauge along the bottom of the view. The gauge SHALL label each of the four zones, highlight the current zone and update at least once per second.

#### Scenario: Gauge follows the session
- **WHEN** a session is running after calibration
- **THEN** the gauge at the bottom of the live view moves at least every second and names the current zone

#### Scenario: Signal unavailable
- **WHEN** the focus score is unavailable because of artifacts or a disconnection
- **THEN** the gauge shows that the reading is unavailable instead of a position, and does not show a zone

### Requirement: Scale in the session record
The app SHALL record the scale zone for each second of a session (the position is the recorded focus score). The summary SHALL show how much time was spent in each of the four zones.

#### Scenario: Summary shows zone times
- **WHEN** a session ends after time spent in Relaxation and Concentration
- **THEN** the summary shows the time spent in each of the four zones, excluding gaps and unavailable seconds
