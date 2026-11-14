import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/band_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../coverage_fixtures.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// A canvas that keeps the lines drawn on it, and where words are set.
class _Drawn implements Canvas {
  final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
  final List<Offset> words = <Offset>[];
  final List<Matrix4> _saved = <Matrix4>[];
  Matrix4 _now = Matrix4.identity();

  Offset _on(Offset p) => MatrixUtils.transformPoint(_now, p);

  @override
  void save() => _saved.add(_now.clone());

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() => _now = _saved.removeLast();

  @override
  void translate(double dx, double dy) => _now.translateByDouble(dx, dy, 0, 1);

  @override
  void scale(double sx, [double? sy]) => _now.scaleByDouble(sx, sy ?? sx, 1, 1);

  @override
  void rotate(double radians) => _now.rotateZ(radians);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((_on(p1), _on(p2)));

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      words.add(_on(offset));

  // Everything else it draws is neither.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<ZoomInks> _inks(WidgetTester tester) async {
  late ZoomInks inks;
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
  return inks;
}

/// The ticks drawn at [y]: lines 8 pixels tall standing across it.
List<double> _ticksAt(_Drawn drawn, double y) => <double>[
  for (final (Offset a, Offset b) in drawn.lines)
    if ((a.dx - b.dx).abs() < 1e-6 &&
        ((a.dy - (y - 4)).abs() < 1e-6 && (b.dy - (y + 4)).abs() < 1e-6))
      a.dx,
];

/// What a set of numbers must be: each whole on the canvas, the zoom's
/// margin in from its edges; each over its mark, or beginning within the
/// margin of it; none within [numberGap] of the next; each painted where it
/// is set.
void _expectSet(
  List<MarkNumber> numbers,
  Size canvas,
  _Drawn drawn,
  String what,
) {
  Rect? previous;
  for (final MarkNumber n in numbers) {
    final Rect? box = n.box;
    expect(box, isNotNull, reason: '$what: "${n.text}" is left out');
    box!;
    expect(
      box.left >= canvasMargin - 1e-6 &&
          box.right <= canvas.width - canvasMargin + 1e-6,
      isTrue,
      reason: '$what: "${n.text}" is not whole on the canvas at $box',
    );
    final bool over = box.left - 1e-6 <= n.mark && n.mark <= box.right + 1e-6;
    final bool beside =
        (box.left - n.mark).abs() <= canvasMargin + 1e-6 ||
        (n.mark - box.right).abs() <= canvasMargin + 1e-6;
    expect(
      over || beside,
      isTrue,
      reason: '$what: "${n.text}" is not over its mark at ${n.mark}: $box',
    );
    if (previous != null) {
      expect(
        box.left - previous.right >= numberGap - 1e-6,
        isTrue,
        reason: '$what: "${n.text}" touches the number before it',
      );
    }
    previous = box;
    expect(
      drawn.words.any(
        (Offset at) => (at - box.topLeft).distance < 1e-6,
      ),
      isTrue,
      reason: '$what: "${n.text}" is not painted where it is set',
    );
  }
}

void main() {
  setUpAll(() async {
    final FontLoader loader = FontLoader(AppTypography.sansFamily);
    for (final String path in <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
    ]) {
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view(File(path).readAsBytesSync().buffer),
        ),
      );
    }
    await loader.load();
  });

  // The canvases the zoom gives a protein on the iPhone 17 Pro, a 390 by 844
  // phone and the 375 by 667 floor.
  const List<Size> canvases = <Size>[
    Size(338, 640),
    Size(326, 610),
    Size(311, 433),
  ];
  // B2M's "50 Mb", lysozyme's "72 Mb" and leptin's "127 Mb" and "130 Mb"
  // were cut at the canvas's edge when each number was centred on its tick.
  const List<String> slugs = <String>['b2m', 'lysozyme', 'leptin'];

  testWidgets('the band’s ruler sets every number whole on the canvas, over '
      'its tick, and draws every tick', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final String slug in slugs) {
      final ProteinTarget t = zoomTarget(slug);
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      for (final Size canvas in canvases) {
        final String what = '$slug at ${canvas.width}';
        int seen = 0;
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          stage.depth.depthOf(ZoomStop.band),
          canvas,
          inks,
          labels: labels,
        )) {
          if (scene is! BandScene) {
            continue;
          }
          seen++;
          final List<MarkNumber> numbers = scene.rulerNumbers(frame);
          expect(numbers, isNotEmpty, reason: what);
          final _Drawn drawn = _Drawn();
          scene.paint(drawn, frame);
          final double y = scene.stripY(frame) + BandScene.rulerY;
          expect(
            _ticksAt(drawn, y),
            <double>[for (final MarkNumber n in numbers) n.mark],
            reason: '$what: every tick is drawn',
          );
          _expectSet(numbers, canvas, drawn, what);
          // Each was cut once at the canvas's edge: it is now moved inward.
          expect(
            numbers.any(
              (MarkNumber n) =>
                  (n.box!.left - (n.mark - n.size.width / 2)).abs() > 1e-6,
            ),
            isTrue,
            reason: '$what: an edge number is moved',
          );
        }
        expect(seen, 1, reason: what);
      }
    }
  });

  testWidgets('the gene’s ruler and its exons’ numbers are set whole on the '
      'canvas, over their marks', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final String slug in slugs) {
      final ProteinTarget t = zoomTarget(slug);
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      for (final Size canvas in canvases) {
        final String what = '$slug at ${canvas.width}';
        int seen = 0;
        for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
          stage.depth.depthOf(ZoomStop.gene),
          canvas,
          inks,
          labels: labels,
        )) {
          if (scene is! GeneScene || scene.annotationsShown(frame) <= 0) {
            continue;
          }
          seen++;
          final _Drawn drawn = _Drawn();
          scene.paint(drawn, frame);
          final List<MarkNumber> ruler = scene.rulerNumbers(frame);
          expect(ruler, isNotEmpty, reason: what);
          final double y = canvas.height / 2 + GeneScene.rulerY;
          // Every tick, the 5′ end's among them where it is in view, which
          // is not numbered.
          final List<double> ticks = _ticksAt(drawn, y);
          expect(
            ticks.length - ruler.length,
            inInclusiveRange(0, 1),
            reason: '$what: every tick is drawn',
          );
          for (final MarkNumber n in ruler) {
            expect(ticks, contains(n.mark), reason: '$what: "${n.text}"');
          }
          _expectSet(ruler, canvas, drawn, '$what, gene ruler');
          final List<MarkNumber> exons = scene.exonNumbers(frame);
          for (final MarkNumber n in exons) {
            final Rect? box = n.box;
            expect(box, isNotNull, reason: '$what: exon ${n.text} left out');
            expect(
              box!.left >= canvasMargin - 1e-6 &&
                  box.right <= canvas.width - canvasMargin + 1e-6,
              isTrue,
              reason: '$what: exon ${n.text} is not whole on the canvas',
            );
            expect(
              drawn.words.any(
                (Offset at) => (at - box.topLeft).distance < 1e-6,
              ),
              isTrue,
              reason: '$what: exon ${n.text} is not painted where it is set',
            );
          }
        }
        expect(seen, 1, reason: what);
      }
    }
  });
}
