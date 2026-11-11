# Hardware notes

## Mindo and the BrainBit SDK

What is known without the band (from the BrainBit Neurofeedback 1.3.5 app
and the neurosdk2 1.0.21 package):

- The vendor app talks to Mindo through neurosdk2's **Headband** device type
  (`SensorLEHeadband` = 11), using `addSignalDataCallbackHeadband` and
  `addResistCallbackHeadband`.
- The SDK frees signal buffers as soon as its callback returns, so signal
  and resistance callbacks go through a small C++ shim
  (`native/fm_shim.cpp`, built by `hook/build.dart`) that copies each batch
  before handing it to Dart.
- Loading `libneurosdk2.dylib` in the `flutter test` host blocks in its
  Bluetooth start-up (and macOS may quarantine the file), so tests never
  load it; the app loads it on the first scan.
- `HeadbandSignalData` is `{PackNum, Marker, O1, O2, T3, T4}` in volts;
  `HeadbandResistData` is `{PackNum, O1, O2, T3, T4}` in ohms.
- The macOS `libneurosdk2.dylib` in the `neurosdk2` Flutter package exports
  these functions; the package's Dart API does not expose them, so the app
  binds them itself (`lib/headband/ffi/`).

## To fill in with the real band (tasks 2.3–2.4, 7.2)

| Item | Value |
|---|---|
| Reported `SensFamily` / `SensModel` | 4 (BrainBit Black) per EEGWaves, which scans families 3 + 4 and uses the BrainBit callbacks; model _pending_ |
| Sampling rate (`readSamplingFrequencySensor`) | _pending (expected 250 Hz)_ |
| Resistance with good contact | _pending_ |
| Resistance with poor contact | _pending_ |
| Contact thresholds used (`lib/headband/models.dart`) | good < 500 kΩ, fair < 2 MΩ (initial guess) |
| Score smoothing (EMA τ) | 3 s (initial guess) |
| Default focus threshold | 40 (initial guess, see note below) |
| Default baseline / scale span | 50 / 50 % (initial guess, see note below) |
| Scale zone bands (±1 span → 12 / 50 / 88 at baseline 50) | _pending: do the zones match how focused or relaxed it felt?_ |
| Typical theta / alpha / beta shares, eyes open, at rest | _pending_ |
| Same, during focused work | _pending (expect more beta)_ |
| False alarms in a 25-minute session | _pending_ |

### Note on the score scale

`EmotionalMath`'s `relAttention` and `relRelaxation` are relative to the
calibration level and one-sided: with simulated EEG, attention reads about
0 at the calibration level and about 70 at a much more focused level, while
relaxation reads up to about 300 at a much less focused one. The app uses
their difference (the focus index) and maps it with `ScoreScale`
(`lib/focus/focus_score.dart`): the calibration level scores the baseline
(default 50, adjustable in Settings) and the score saturates towards 0 and
100. The span (50 %) and the defaults must be checked against real Mindo
data in task 7.2.

### Note on rhythm shares

The estimator zeroes delta and gamma (`setZeroSpectWaves(true, 0, 1, 1, 1,
0)`), as EEGWaves does, so `readSpectralDataPercents()` gives theta, alpha
and beta shares that add up to 100. With simulated EEG, beta rises and
alpha + theta fall as focus rises. On real Mindo data, check that resting
with eyes closed raises alpha, and that dry-electrode noise doesn't inflate
beta.
