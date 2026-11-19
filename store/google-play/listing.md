# Google Play listing

Everything to paste into Play Console for **Focused Relaxed Mind**
(`com.kashubianrodos.focusedmind`). Graphics are in this folder.

## Main store listing

**App name** (30 max)

```
Focused Relaxed Mind
```

**Short description** (80 max)

```
EEG neurofeedback for focus and meditation, with calming soundscapes.
```

**Full description** (4000 max)

```
Focused Relaxed Mind turns your EEG headband into a real-time focus and meditation coach.

Put on a BrainBit-family headband (developed with the Mindo band), start a session, and see every second how focused or how calm you are. A soundscape of birds, ocean or forest gently guides you: it fades in when your focus drifts, or plays louder the deeper you relax.

TWO SESSION MODES
• Focus: rewards concentration. Choose Alert feedback (quiet while you are focused, sound when you drift) or Continuous feedback (louder the more focused you are).
• Meditation: rewards a calm, relaxed state. The calm score rises as you relax and the soundscape deepens with you.

LIVE VIEW
• Focus or calm score every second, with your state and a graph of the whole session
• Relaxation–concentration scale with four zones, centred on your own calibrated level
• Brain rhythms: theta, alpha and beta shares as a pie and over time
• Sessions of 25, 50 or 90 minutes or open-ended, with a short signal check and calibration first
• Keeps running in the background while you use other apps

SUMMARY AND HISTORY
• Time per state and per zone, focus drops or restless episodes, your longest focused or calm stretch, and average rhythms
• Export any session as a CSV file to Downloads, with an optional raw EEG recording

PRIVATE BY DESIGN
No account, no ads, no tracking. All data stays on your device.

REQUIREMENTS
A BrainBit-family EEG headband connected over Bluetooth, and Android 11 or later. No headband yet? Pick "Simulated headband" in the scan list to try the app.

The focus and calm scores are estimates for personal wellness use. Focused Relaxed Mind is not a medical device.
```

**Graphics**

| Field | File |
|---|---|
| App icon (512×512) | `icon-512.png` |
| Feature graphic (1024×500) | `feature-graphic-1024x500.png` |
| Phone screenshots (1080×1920) | `phone-1-focus-session.png`, `phone-2-meditation-session.png`, `phone-3-session-modes.png` |

## Store settings

- **App category:** Health & Fitness
- **Tags:** Meditation, Mindfulness, Focus (pick the closest ones offered)
- **Contact email:** required and shown publicly on the listing
- **Website:** https://github.com/kashubianrodos/focused-mind
- **Privacy policy:** https://kashubianrodos.github.io/focused-mind/privacy.html

## App content (Policy › App content)

**Privacy policy:** https://kashubianrodos.github.io/focused-mind/privacy.html

**Ads:** No, the app does not contain ads.

**App access:** All functionality is available without special access.
Add instructions anyway, because review has no headband:

```
The app needs a BrainBit-family EEG headband over Bluetooth. To review without one:
1. On the Focus tab, tap Scan: "Simulated headband" is always listed (also with Bluetooth off). Tap it to connect.
2. Pick Focus or Meditation, choose a length and tap Start session. After the signal check and calibration, the live score, scale, rhythms and soundscape run from simulated EEG.
No account or login is needed.
```

**Content rating** (IARC questionnaire): category *Reference, News, or
Educational* or *All other app types*; answer **No** to every question
(violence, sexuality, language, controlled substances, gambling, user
interaction, sharing location, digital purchases). Expected rating: Everyone
/ PEGI 3.

**Target audience:** 18 and over (avoids the Families policy; the app is
not designed for children).

**News app:** No.

**Data safety:**
- Does your app collect or share any of the required user data types? **No**
- (Data stays on the device and is never transmitted, which Google does not
  count as collection.)
- Is all data encrypted in transit? Not applicable (no data leaves the device).
- Account deletion: not applicable, no accounts.

**Health apps declaration:** the app offers health and fitness features:
tick **Meditation / mindfulness / stress management** (or the closest
wellness option). Not a medical device, no Health Connect, no clinical use.

**Government apps / Financial features:** No / None.

**Foreground service permissions** (`FOREGROUND_SERVICE_CONNECTED_DEVICE`):

```
Type: Connected device.
The app keeps a foreground service running during a focus or meditation session so it can keep receiving EEG data from the user's Bluetooth headband and play audio feedback while the user switches to other apps or turns the screen off. The service starts only when the user starts a session, shows an ongoing "Focus session running" notification, and stops when the session ends. Without it, Android would stop the Bluetooth stream and the session would be interrupted.
```

Video: record about 30 seconds on a phone: start a session (the simulated
headband is fine), switch to the home screen, show the "Focus session running"
notification, return to the app with the session still running. Upload it
unlisted (e.g. YouTube) and paste the link.

**Bluetooth / location:** `ACCESS_FINE_LOCATION` is declared only up to
Android 11 (`maxSdkVersion 30`), where Bluetooth scans need it; no location
declaration is needed.

## Release notes (first release)

```
First release: real-time focus and meditation feedback from your BrainBit-family EEG headband, with birds, ocean and forest soundscapes.
```
