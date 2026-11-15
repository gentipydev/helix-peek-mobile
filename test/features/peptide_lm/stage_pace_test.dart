import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/stage_pace.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/peptide_lm_screen.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene_painter.dart';

import 'support/toy_trace.dart';

/// Scores' captions at step 1, where each starts and how long it is: a
/// stage that changes its words often.
const List<PaceCaption> _scores = <PaceCaption>[
  PaceCaption(0, 61),
  PaceCaption(0.95, 66),
  PaceCaption(2.5, 44),
  PaceCaption(3.2, 56),
  PaceCaption(3.9, 58),
  PaceCaption(4.8, 62),
  PaceCaption(6.6, 54),
  PaceCaption(7.7, 60),
  PaceCaption(9.35, 60),
  PaceCaption(10.35, 59),
  PaceCaption(11.45, 55),
  PaceCaption(12.7, 57),
  PaceCaption(13.5, 62),
  PaceCaption(14.8, 56),
  PaceCaption(16.35, 40),
  PaceCaption(17.3, 54),
  PaceCaption(18.5, 54),
];

/// Where each caption's stretch ends: at the next caption, or the stage's.
List<(double, double, int)> _stretches(double beats, List<PaceCaption> captions) => <(double, double, int)>[
  for (int i = 0; i < captions.length; i++)
    (captions[i].from, i + 1 < captions.length ? captions[i + 1].from : beats, captions[i].characters),
];

void main() {
  test('a stage that says one thing plays every beat in the four seconds, twice what it took', () {
    final StagePace pace = StagePace.even(11);
    expect(StagePace.secondsPerBeat, 2 * 2);
    expect(pace.seconds, 44);
    expect(pace.duration, const Duration(seconds: 44));
    for (final double local in <double>[0, 0.1, 0.5, 0.93, 1]) {
      expect(pace.localAt(local), closeTo(local, 1e-12));
      expect(pace.secondsPerBeatAt(local * 11), 4);
    }
  });

  test('each caption stays at least as long as it takes to read, and at least twice as long as it did', () {
    final StagePace pace = StagePace(20, _scores);
    double total = 0;
    for (final (double from, double to, int characters) in _stretches(20, _scores)) {
      final double least = math.max(4 * (to - from), StagePace.readingSeconds(characters));
      total += least;
      // The ease at a change trades a little time across it, never more
      // than a quarter of the blend at either end at the larger pace.
      const double slack = 2 * StagePace.blend / 4 * 12;
      expect(pace.secondsBetween(from, to), greaterThan(least - slack), reason: 'caption at $from');
    }
    // Easing keeps each change's time: the stage is the sum of its stretches.
    expect(pace.seconds, closeTo(total, 1e-9));
    // A caption of 40 characters or fewer reads in five seconds; one of 66
    // in nearly seven; none in more than eight.
    expect(StagePace.readingSeconds(40), 5);
    expect(StagePace.readingSeconds(66), closeTo(2 + 66 / 14, 1e-12));
    expect(StagePace.readingSeconds(400), 8);
  });

  test('the pace runs one way, from the start to the end, and reads back', () {
    for (final StagePace pace in <StagePace>[StagePace(20, _scores), StagePace.even(5)]) {
      expect(pace.localAt(0), 0);
      expect(pace.localAt(1), 1);
      expect(pace.fractionAt(0), 0);
      expect(pace.fractionAt(1), 1);
      double before = 0;
      for (int i = 1; i <= 4000; i++) {
        final double fraction = i / 4000;
        final double local = pace.localAt(fraction);
        expect(local, greaterThan(before), reason: 'at $fraction');
        expect(pace.fractionAt(local), closeTo(fraction, 1e-9), reason: 'at $fraction');
        before = local;
      }
    }
  });

  test('the speed eases from one caption to the next, never jumping', () {
    final StagePace pace = StagePace(20, _scores);
    final List<double> paces = <double>[for (int i = 0; i <= 2000; i++) pace.secondsPerBeatAt(i / 100)];
    final double spread = paces.reduce(math.max) - paces.reduce(math.min);
    expect(spread, greaterThan(1));
    for (int i = 1; i < paces.length; i++) {
      // Over a hundredth of a beat, at most its share of a whole change
      // eased over twice the blend.
      expect((paces[i] - paces[i - 1]).abs(), lessThanOrEqualTo(spread * 0.01 / (2 * StagePace.blend) + 1e-9), reason: 'at ${i / 100}');
    }
  });

  test('a caption on screen for a moment, or with nothing to read, keeps the page beat', () {
    final StagePace pace = StagePace(10, const <PaceCaption>[
      PaceCaption(0, 60),
      PaceCaption(4, 70),
      PaceCaption(4.1, 60),
      PaceCaption(8, 0),
    ]);
    expect(pace.secondsPerBeatAt(4.05), 4);
    expect(pace.secondsPerBeatAt(9), 4);
  });

  testWidgets('every stage of a run plays at least twice as slowly, each caption long enough to read', (
    WidgetTester tester,
  ) async {
    final TrainingTrace trace = toyTrace();
    late LmView view;
    late LmKit kit;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            kit = LmKit(
              mono: AppTypography.sequenceSmall(theme.colorScheme.onSurfaceVariant),
              sans: theme.caption!,
              scaler: TextScaler.noScaling,
            );
            view = LmView(
              trace: trace,
              checkpoint: trace.checkpoints.first,
              peptide: 0,
              position: trace.peptides.first.inputs ~/ 2,
              inks: LmInks.of(context),
              kit: kit,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    addTearDown(kit.dispose);
    const TrainingTimeline timeline = TrainingTimeline();
    for (final LmStage stage in LmStage.values) {
      final StagePace pace = TrainingRunView.paceOf(stage, view);
      expect(pace.seconds, greaterThanOrEqualTo(2 * 2 * stage.beats - 1e-9), reason: stage.name);
      // Each caption's stretch, as sampled every sixteenth of a beat.
      String at(double beat) => sceneOf(stage).caption(view, timeline.frameIn(stage, beat / stage.beats));
      final List<(double, double, String)> stretches = <(double, double, String)>[];
      String shown = at(0);
      double from = 0;
      for (int k = 1; k <= stage.beats * 16; k++) {
        final String now = at(k / 16);
        if (now != shown) {
          stretches.add((from, k / 16, shown));
          shown = now;
          from = k / 16;
        }
      }
      stretches.add((from, stage.beats.toDouble(), shown));
      double most = 0;
      for (int i = 0; i <= stage.beats * 100; i++) {
        most = math.max(most, pace.secondsPerBeatAt(i / 100));
      }
      // A sampled end is a sixteenth of a beat off at most, and the ease
      // trades a little time across each change.
      final double slack = (2 / 16 + StagePace.blend) * most;
      for (final (double a, double b, String text) in stretches) {
        if (b - a < 0.5 || text.isEmpty) {
          continue;
        }
        final double least = math.max(4 * (b - a), StagePace.readingSeconds(text.length));
        expect(pace.secondsBetween(a, b), greaterThan(least - slack), reason: '${stage.name}: "$text"');
      }
    }
  });
}
