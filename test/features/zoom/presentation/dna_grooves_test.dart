import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromatin_fibre.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/dna_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/gene_strand.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../coverage_fixtures.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

/// What a scene draws, on screen: every line (the helix's painter draws its
/// backbones as lines) and every stroked path (the DNA's body and ridges),
/// each through the transforms in force when it is drawn.
class _Screen implements Canvas {
  _Screen();

  /// The transform in force: x' = a x + c y + e, y' = b x + d y + f.
  List<double> _m = <double>[1, 0, 0, 1, 0, 0];
  final List<List<double>> _saved = <List<double>>[];

  final List<(Offset, Offset, Color, double)> lines =
      <(Offset, Offset, Color, double)>[];
  final List<(Path, Paint)> paths = <(Path, Paint)>[];

  Offset _map(Offset p) => Offset(
    _m[0] * p.dx + _m[2] * p.dy + _m[4],
    _m[1] * p.dx + _m[3] * p.dy + _m[5],
  );

  @override
  void save() => _saved.add(List<double>.of(_m));

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() => _m = _saved.removeLast();

  @override
  int getSaveCount() => _saved.length + 1;

  @override
  void translate(double dx, double dy) {
    _m[4] += _m[0] * dx + _m[2] * dy;
    _m[5] += _m[1] * dx + _m[3] * dy;
  }

  @override
  void scale(double sx, [double? sy]) {
    final double y = sy ?? sx;
    _m[0] *= sx;
    _m[1] *= sx;
    _m[2] *= y;
    _m[3] *= y;
  }

  @override
  void rotate(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    final double a = _m[0];
    final double b = _m[1];
    _m[0] = a * c + _m[2] * s;
    _m[1] = b * c + _m[3] * s;
    _m[2] = -a * s + _m[2] * c;
    _m[3] = -b * s + _m[3] * c;
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((_map(p1), _map(p2), paint.color, paint.strokeWidth));

  @override
  void drawPath(Path path, Paint paint) {
    if (paint.style != PaintingStyle.stroke) {
      return;
    }
    // Scale and turn only where a path is drawn under a transform: the
    // DNA's are drawn in screen pixels.
    paths.add((path, paint));
  }

  // Everything else it draws is neither.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

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

/// The depth on the step from the gene to the DNA at which the view is
/// [width] base pairs across.
double _depthWhere(ZoomDepth depth, double width) {
  double high = depth.depthOf(ZoomStop.gene);
  double low = depth.depthOf(ZoomStop.dna);
  for (int i = 0; i < 80; i++) {
    final double mid = (high + low) / 2;
    if (depth.widthAt(mid) > width) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return (high + low) / 2;
}

(DnaScene, ZoomFrame) _dna(
  ZoomStage stage,
  double d,
  ZoomInks inks, {
  double clock = 0,
}) {
  for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
    d,
    _canvas,
    inks,
    clock: clock,
  )) {
    if (scene is DnaScene) {
      return (scene, frame);
    }
  }
  throw StateError('no DNA at $d');
}

/// How far from where a backbone of [grooves] lies at screen x [x] the
/// point ([x], [y]) is, either backbone, on a duplex [thick] pixels thick
/// about the line at [mid], the screen's x of [offset] given by [xOf].
double _offFormula(
  DnaGrooves grooves,
  double thick,
  double mid,
  double x,
  double y,
  double Function(double screenX) offsetOf,
) {
  final double offset = offsetOf(x);
  double best = double.infinity;
  for (final bool second in <bool>[false, true]) {
    final (double across, bool _) = DnaGrooves.across(
      grooves.angleAt(offset, second: second),
      thick,
    );
    best = math.min(best, (mid + across - y).abs());
  }
  return best;
}

void main() {
  final List<ProteinTarget> genes = <ProteinTarget>[
    TestCatalog.insulin,
    TestCatalog.oxytocin,
    TestCatalog.bySlug('lactalbumin')!,
  ];

  testWidgets('the helix’s painter draws its backbones where the DNA’s '
      'grooves put them, at every turn, as its skin clears', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in genes) {
      final ZoomStage stage = _stage(t);
      for (final double span in <double>[300, 260, 230]) {
        for (final double clock in <double>[0, 5.5, 13]) {
          final (DnaScene scene, ZoomFrame frame) = _dna(
            stage,
            _depthWhere(stage.depth, span),
            inks,
            clock: clock,
          );
          final DnaGrooves grooves = scene.groovesOf(frame)!;
          expect(grooves.cleared, greaterThan(0), reason: t.slug);
          final double thick = scene.thickAt(frame);
          final double mid = _canvas.height / 2;
          final double x0 = scene.dnaX(frame, 0);
          final double perBase = scene.dnaX(frame, 1) - x0;
          double offsetOf(double x) => (x - x0) / perBase;
          final _Screen screen = _Screen();
          scene.paintAmbient(screen, frame);
          // No bases show this far out: every line is a backbone.
          expect(screen.lines, isNotEmpty, reason: '${t.slug} at $span');
          for (final (Offset a, Offset b, Color _, double _) in screen.lines) {
            for (final Offset p in <Offset>[a, b]) {
              final double offset = offsetOf(p.dx);
              if (offset < 0.5 || offset > grooves.anchor - 0.5) {
                continue;
              }
              expect(
                _offFormula(grooves, thick, mid, p.dx, p.dy, offsetOf),
                lessThan(0.3),
                reason: '${t.slug} at $span bp, clock $clock, base $offset',
              );
            }
          }
        }
      }
    }
  });

  testWidgets('the DNA’s backbones lie where the helix’s would, the near '
      'halves in their own colour and the far ones in shade, before its skin '
      'clears and as it does', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in genes) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final double scale = subject.track.geneLengthBp / subject.layout.length;
      for (final double span in <double>[600, 400, 300, 200]) {
        for (final double clock in <double>[0, 5.5, 13]) {
          final (DnaScene scene, ZoomFrame frame) = _dna(
            stage,
            _depthWhere(stage.depth, span),
            inks,
            clock: clock,
          );
          final DnaGrooves grooves = scene.groovesOf(frame)!;
          final double thick = scene.thickAt(frame);
          final double mid = _canvas.height / 2;
          final double x0 = scene.dnaX(frame, 0);
          final double perBase = scene.dnaX(frame, 1) - x0;
          double offsetOf(double x) => (x - x0) / perBase;
          // A backbone's colour where it is near, and where it is far.
          (Color, Color) inksAt(double offset) {
            final Color body = GeneStrand.ink(
              inks,
              subject.layout.kindAt(offset / scale),
            );
            final Color near = Color.lerp(
              body,
              GeneStrand.ridge(body, inks),
              grooves.shown,
            )!;
            return (near, Color.lerp(near, inks.ground, 0.45)!);
          }

          final _Screen screen = _Screen();
          scene.paintAmbient(screen, frame);
          int near = 0;
          int far = 0;
          for (final (Path path, Paint paint) in screen.paths) {
            // The backbones: round-capped, no wider than the painter's.
            if (paint.strokeCap != StrokeCap.round ||
                paint.strokeWidth > DnaGrooves.strand + 1e-9) {
              continue;
            }
            for (final ui.PathMetric metric in path.computeMetrics()) {
              for (double at = 0; at <= metric.length; at += 0.5) {
                final Offset p = metric.getTangentForOffset(at)!.position;
                final double offset = offsetOf(p.dx);
                // Along the bare start, where the DNA lies straight.
                if (offset < 1 || offset > grooves.anchor - 1) {
                  continue;
                }
                final String what = '${t.slug} at $span bp, clock $clock, '
                    'base $offset';
                expect(
                  _offFormula(grooves, thick, mid, p.dx, p.dy, offsetOf),
                  lessThan(0.3),
                  reason: what,
                );
                // Its colour is its stretch's: within half a base of where
                // the stretch changes, either side's.
                final int drawn = paint.color.toARGB32();
                bool isNear = false;
                bool known = false;
                for (final double side in <double>[-0.5, 0, 0.5]) {
                  final (Color nearInk, Color farInk) = inksAt(offset + side);
                  if (drawn == nearInk.toARGB32()) {
                    isNear = true;
                    known = true;
                  } else if (drawn == farInk.toARGB32()) {
                    known = true;
                  }
                }
                expect(known, isTrue, reason: '$what: a backbone’s colour');
                // On the side of the duplex its colour says: the backbone
                // there faces the reader, or does not.
                final bool sided = <bool>[false, true].any((bool second) {
                  final double angle = grooves.angleAt(offset, second: second);
                  final (double across, bool facing) = DnaGrooves.across(
                    angle,
                    thick,
                  );
                  return (mid + across - p.dy).abs() < 0.3 &&
                      (facing == isNear || math.sin(angle).abs() < 0.35);
                });
                expect(sided, isTrue, reason: '$what: its side');
                isNear ? near++ : far++;
              }
            }
          }
          expect(near, greaterThan(0), reason: '${t.slug} at $span: near');
          expect(far, greaterThan(0), reason: '${t.slug} at $span: far');
        }
      }
    }
  });

  testWidgets('the DNA is drawn still while no grooves show, and on the '
      'ambient clock once they do, never both', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in zoomProteins) {
      final ZoomStage stage = _stage(t);
      for (final double span in <double>[2000, 1000, 901, 899, 600, 200]) {
        final double gene = stage.depth.widthOf(ZoomStop.gene);
        if (span > gene) {
          continue;
        }
        final (DnaScene scene, ZoomFrame frame) = _dna(
          stage,
          _depthWhere(stage.depth, span),
          inks,
        );
        final _Screen still = _Screen();
        scene.paint(still, frame);
        final _Screen moving = _Screen();
        scene.paintAmbient(moving, frame);
        final bool grooved = scene.groovesShown(frame) > 0;
        expect(
          still.paths.isEmpty,
          grooved,
          reason: '${t.slug} at $span: the still layer',
        );
        expect(
          moving.paths.isNotEmpty,
          grooved,
          reason: '${t.slug} at $span: the moving layer',
        );
        expect(
          scene.wantsClock(frame),
          grooved,
          reason: '${t.slug} at $span',
        );
      }
      // The narrowest gene's stop is wider than where the grooves start.
      expect(DnaScene.groovesAt(ZoomDepth.leastGeneView), 0);
    }
  });

  testWidgets('the skin clears onto the helix left of the edge the helix '
      'fades at, on every gene’s step at 60 fps; and at the helix’s stop '
      'nothing of the DNA is drawn but the helix, its backbones in the quiet '
      'ink', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in zoomProteins) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      final double from = depth.depthOf(ZoomStop.gene);
      final double to = depth.depthOf(ZoomStop.dna);
      final double bases = stage.subject.dnaBases.toDouble();
      final ZoomFlight flight = ZoomFlight(
        from,
        to,
        minimum: depth.leastFlight(from, to),
        cruise: depth.cruiseOf(from, to),
      );
      final int count = (flight.duration.inMicroseconds / 1e6 * 60).ceil();
      for (int f = 0; f <= count; f++) {
        final (DnaScene scene, ZoomFrame frame) = _dna(
          stage,
          flight.at(Duration(microseconds: (f * 1e6 / 60).round())),
          inks,
        );
        final (double cleared, double _) = scene.helixShown(frame);
        if (cleared > 0 && cleared < 1) {
          expect(
            scene.dnaX(frame, bases),
            lessThanOrEqualTo(_canvas.width * 0.72 + 0.5),
            reason: '${t.slug}, frame $f',
          );
        }
      }
      for (final double clock in <double>[0, 7, 30]) {
        final (DnaScene scene, ZoomFrame frame) = _dna(
          stage,
          to,
          inks,
          clock: clock,
        );
        final _Screen screen = _Screen();
        scene.paintAmbient(screen, frame);
        expect(screen.paths, isEmpty, reason: '${t.slug} at its stop');
        expect(scene.backboneAt(frame), inks.label, reason: t.slug);
      }
    }
  });
}
