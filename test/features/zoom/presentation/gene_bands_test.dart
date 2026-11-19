import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/gene_layout.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_strand.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

/// What a scene draws, in order: a band is a rounded rectangle, and a
/// nucleosome's core, its shadow and its face, are ovals.
class _Order implements Canvas {
  final List<String> drawn = <String>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => drawn.add('band');

  @override
  void drawOval(Rect rect, Paint paint) => drawn.add('core');

  // Everything else it draws is neither.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late ZoomInks inks;

  Future<void> theInks(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = ZoomInks.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('the DNA along an exon wears the gene’s colours: its coding '
      'part the mark, its untranslated ends the home tone, the rest the '
      'DNA’s own ink, and the bands behind it are quieter than either', (
    WidgetTester tester,
  ) async {
    await theInks(tester);
    expect(GeneStrand.ink(inks, GenePieceKind.cds), inks.mark);
    expect(GeneStrand.ink(inks, GenePieceKind.utr), inks.home);
    expect(GeneStrand.ink(inks, GenePieceKind.intron), GeneStrand.dna(inks));
    // A band is a region behind the chromatin: darker than the DNA it
    // holds, and a coding band brighter than an untranslated one.
    double light(Color c) => c.computeLuminance();
    final Color coding = GeneStrand.band(inks, GenePieceKind.cds);
    final Color untranslated = GeneStrand.band(inks, GenePieceKind.utr);
    expect(light(coding), lessThan(light(inks.home)));
    expect(light(untranslated), lessThan(light(coding)));
    expect(light(untranslated), greaterThan(light(inks.ground)));
    expect(GeneStrand.coding, greaterThan(GeneStrand.untranslated));
  });

  testWidgets('no band covers a nucleosome: on the step to the gene and at '
      'its stop, every band is drawn before the first core', (
    WidgetTester tester,
  ) async {
    await theInks(tester);
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.dystrophin,
      TestCatalog.prion,
      TestCatalog.relaxin,
    ]) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final double band = stage.depth.depthOf(ZoomStop.band);
      final double gene = stage.depth.depthOf(ZoomStop.gene);
      for (final double d in <double>[
        band + (gene - band) * 0.8,
        gene - 1e-9,
        gene,
      ]) {
        int scenes = 0;
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          d,
          _canvas,
          inks,
        )) {
          if (scene is! GeneScene && scene is! DnaScene) {
            continue;
          }
          final _Order order = _Order();
          scene.paint(order, frame);
          final int lastBand = order.drawn.lastIndexOf('band');
          final int firstCore = order.drawn.indexOf('core');
          if (lastBand < 0) {
            continue;
          }
          scenes++;
          expect(firstCore, greaterThan(lastBand), reason: '${t.slug} at $d');
        }
        expect(scenes, 1, reason: '${t.slug} at $d: one scene draws them');
      }
    }
  });
}
