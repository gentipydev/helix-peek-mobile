import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_inks.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/embedding_scene.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_drawing.dart';
import 'package:helixpeek/features/peptide_lm/presentation/scenes/lm_scene.dart';

import 'support/toy_trace.dart';

/// No outline is drawn over another: where two would meet, they share an
/// edge or one gives way.
void main() {
  final TrainingTrace trace = toyTrace();

  Future<(LmInks, LmKit)> drawing(WidgetTester tester) async {
    late LmInks inks;
    late LmKit kit;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            inks = LmInks.of(context);
            kit = LmKit(
              mono: AppTypography.sequenceSmall(theme.colorScheme.onSurfaceVariant),
              sans: theme.caption!,
              scaler: TextScaler.noScaling,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return (inks, kit);
  }

  testWidgets("one token's two places, next to each other, share one edge; apart, each has its own box", (
    WidgetTester tester,
  ) async {
    final (LmInks inks, LmKit kit) = await drawing(tester);
    addTearDown(kit.dispose);
    // The toy's first peptide repeats C at places 6 and 7, next to each
    // other; its second repeats L at 2 and 6.
    for (final (int peptide, int boxes, int lines) in <(int, int, int)>[(0, 1, 1), (1, 2, 0)]) {
      final LmView scene = LmView(
        trace: trace,
        checkpoint: trace.checkpoints.first,
        peptide: peptide,
        position: 3,
        inks: inks,
        kit: kit,
      );
      final EmbeddingLayout layout = EmbeddingLayout(const Size(393, 600), scene);
      void marked(Canvas canvas) => EmbeddingScene.markTwins(canvas, scene, layout, 1);
      expect(marked, paintsExactlyCountTimes(#drawRRect, boxes), reason: 'peptide $peptide');
      expect(marked, paintsExactlyCountTimes(#drawLine, lines), reason: 'peptide $peptide');
    }
  });
}
