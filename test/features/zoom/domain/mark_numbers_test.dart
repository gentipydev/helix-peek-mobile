import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';

/// Where a ruler's numbers and an exon's number are set
/// (`docs/design/zoom.md`, "Numbers on marks stay whole"): centred on their
/// mark, moved inward where that would cut them at the canvas's edge, and
/// left out only where, so moved, a ruler's number would touch the one
/// beside it.
void main() {
  group('a number set on a mark', () {
    test('is centred on it where it is whole in its room', () {
      expect(numberOnMark(100, 40, 8, 318), 80);
    });

    test('is moved inward just far enough where it is not', () {
      // Its mark 6 from the left edge: it begins at the margin, past it.
      expect(numberOnMark(6, 40, 8, 318), 8);
      // Its mark 10 from the right edge: it ends at the margin.
      expect(numberOnMark(316, 40, 8, 318), 278);
    });

    test('is left out where its room is narrower than it', () {
      expect(numberOnMark(20, 40, 8, 40), isNull);
    });
  });

  group('a ruler’s numbers', () {
    const double canvas = 326;

    test('are centred on their ticks where each is whole on the canvas', () {
      expect(
        rulerNumberLefts(<double>[60, 160, 260], <double>[40, 40, 40], canvas),
        <double>[40, 140, 240],
      );
    });

    test('keep the margin: an edge number is moved inward and still lies '
        'over its tick, or begins within the margin of it', () {
      final List<double?> lefts = rulerNumberLefts(
        <double>[2, 105, 208, 311],
        <double>[44, 44, 44, 44],
        canvas,
      );
      expect(lefts.first, canvasMargin);
      expect(lefts.last, canvas - canvasMargin - 44);
      expect(lefts.last! <= 311 && 311 <= lefts.last! + 44, isTrue);
      expect(lefts[1], 105 - 22);
      expect(lefts[2], 208 - 22);
    });

    test('leave an edge number out only where, moved, it would touch the '
        'number beside it; its neighbour stays where it was', () {
      // Ticks 70 apart and numbers 60 wide: the last, moved 34 inward,
      // would overlap the one before it.
      final List<double?> lefts = rulerNumberLefts(
        <double>[112, 182, 252, 322],
        <double>[60, 60, 60, 60],
        canvas,
      );
      expect(lefts, <double?>[82, 152, 222, null]);
    });

    test('never leave a centred number out', () {
      final List<double?> lefts = rulerNumberLefts(
        <double>[40, 163, 286],
        <double>[48, 48, 48],
        canvas,
      );
      expect(lefts.every((double? left) => left != null), isTrue);
    });

    test('of a ruler with one tick near the edge keep it, moved', () {
      expect(rulerNumberLefts(<double>[320], <double>[40], canvas), <double?>[
        canvas - canvasMargin - 40,
      ]);
    });
  });

  group('an exon’s number', () {
    const double canvas = 326;

    test('is centred over its exon where it is whole on the canvas', () {
      expect(exonNumberLeft(100, 140, 10, canvas), 115);
    });

    test('stays over the part of its exon on the canvas', () {
      // The exon runs off the left edge: its number moves right, into the
      // part of it the canvas shows.
      expect(exonNumberLeft(-30, 30, 10, canvas), canvasMargin);
      expect(exonNumberLeft(300, 360, 10, canvas), canvas - canvasMargin - 10);
    });

    test('is left out where the part of its exon on the canvas is narrower '
        'than it', () {
      expect(exonNumberLeft(-30, 14, 10, canvas), isNull);
    });
  });
}
