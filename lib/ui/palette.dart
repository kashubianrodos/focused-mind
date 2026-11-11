import 'package:flutter/material.dart';

import '../focus/focus_score.dart';
import '../focus/rhythms.dart';

/// Colours shared by the scale gauge, rhythm charts and summaries
/// (design D3): cool for relaxation, warm for concentration.
Color zoneColor(FocusZone zone) => switch (zone) {
  FocusZone.deepRelaxation => const Color(0xFF3B6FD8),
  FocusZone.relaxation => const Color(0xFF4FB3C8),
  FocusZone.concentration => const Color(0xFFF2B33D),
  FocusZone.deepConcentration => const Color(0xFFE5673A),
};

Color rhythmColor(Rhythm rhythm) => switch (rhythm) {
  Rhythm.theta => const Color(0xFF8E6BD6),
  Rhythm.alpha => const Color(0xFF3FA7D6),
  Rhythm.beta => const Color(0xFFF08A3C),
};
