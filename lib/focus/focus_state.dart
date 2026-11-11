/// The focus-tracking spec's states, plus [unavailable] for artifacted or
/// missing signal (never reported as low focus).
enum FocusState { focused, neutral, distracted, unavailable }

/// How far above the threshold the score must be to count as focused.
const double focusedMargin = 15;

/// Classifies a smoothed score: distracted < T ≤ neutral < T + 15 ≤ focused.
FocusState classifyFocus(double? score, double threshold) {
  if (score == null) return FocusState.unavailable;
  if (score < threshold) return FocusState.distracted;
  if (score >= threshold + focusedMargin) return FocusState.focused;
  return FocusState.neutral;
}
