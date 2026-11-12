import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/focus/focus_state.dart';
import 'package:focused_mind/sessions/session_models.dart';
import 'package:focused_mind/ui/focus_chart.dart';

void main() {
  testWidgets('the 100 label stays on one line with large text on a phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 390,
              height: 260,
              child: FocusChart(
                points: [
                  for (var s = 0; s < 120; s++)
                    TimelinePoint(
                      second: s,
                      score: 60,
                      state: FocusState.focused,
                    ),
                ],
                marks: const [],
                threshold: 40,
              ),
            ),
          ),
        ),
      ),
    );

    final label = find.byKey(const ValueKey('axis-100'));
    expect(label, findsOneWidget);
    // One line: as tall as the single-digit "0" label.
    final lineHeight = tester
        .getSize(find.byKey(const ValueKey('axis-0')))
        .height;
    expect(tester.getSize(label).height, lineHeight);
  });
}
