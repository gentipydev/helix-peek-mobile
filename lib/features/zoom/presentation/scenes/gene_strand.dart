import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../zoom_inks.dart';

/// The gene's exons as its stop draws them, as a genome browser does: a
/// quiet band behind its chromatin for each, coding parts tall and
/// untranslated ones short, in one hue (the user's choice of 2026-11-18,
/// over lit blocks laid over the nucleosomes, which hid them); and the
/// colours its DNA is drawn in, the gene's own along its exons.
///
/// The gene's scene draws them on the step that reaches the gene, and the
/// DNA's from the gene's stop on, so the hand-over at the stop changes no
/// pixel. On the way to the DNA the bands sink behind the DNA ([bands]'
/// `sink`), down to nothing: the DNA along an exon already wears the
/// exon's colour, from the gene's stop to where its skin clears onto the
/// helix, so nothing gives way but the band.
abstract final class GeneStrand {
  /// The line's width at the gene's stop, in pixels, and how much of the
  /// quiet ink it is drawn in, over the ground.
  static const double line = 1.6;
  static const double lineInk = 0.75;

  /// How far a coding exon's band and an untranslated one's reach above and
  /// below the line, in pixels: a coding band holds a nucleosome as the
  /// gene's stop draws it, some 8 px either side of the line, with air
  /// round it, and stays clear of the 3′ beside the gene's end; an
  /// untranslated one is half as tall.
  static const double coding = 10;
  static const double untranslated = 5;

  /// How far from the ground toward the home tone a coding band is mixed,
  /// and an untranslated one: quiet, a region behind the chromatin, as the
  /// organs' quiet areas are.
  static const double codingBand = 0.35;
  static const double untranslatedBand = 0.2;

  /// The DNA's own colour, where it is no exon: the quiet ink, as the
  /// helix's backbones are, laid on the ground so that it is opaque, and
  /// where two of its strokes meet or cross nothing doubles.
  static Color dna(ZoomInks inks) =>
      Color.lerp(inks.ground, inks.label, lineInk)!;

  /// The colour the DNA is drawn in where it is [kind]: an exon's coding
  /// part in the mark, its untranslated ends in the home tone, the mark's
  /// quieter strength; anything else the DNA's own colour.
  static Color ink(ZoomInks inks, GenePieceKind kind) => switch (kind) {
    GenePieceKind.intron => dna(inks),
    GenePieceKind.cds => inks.mark,
    GenePieceKind.utr => inks.home,
  };

  /// The band behind an exon's part of [kind].
  static Color band(ZoomInks inks, GenePieceKind kind) => Color.lerp(
    inks.ground,
    inks.home,
    kind == GenePieceKind.cds ? codingBand : untranslatedBand,
  )!;

  /// Strokes [path] as a stretch of DNA [width] pixels thick in [colour]:
  /// a line, and once it is thick enough to have one, a lit tube, its upper
  /// edge catching the light.
  static void tube(
    Canvas canvas,
    Path path,
    Color colour,
    double width,
    ZoomInks inks,
  ) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = colour;
    canvas.drawPath(path, stroke);
    final double lit = ((width - 2.5) / 3).clamp(0.0, 1.0);
    if (lit > 0) {
      canvas.drawPath(
        path.shift(Offset(0, -0.2 * width)),
        stroke
          ..strokeWidth = 0.35 * width
          ..color = Color.lerp(
            colour,
            inks.text,
            0.45,
          )!.withValues(alpha: colour.a * 0.55 * lit),
      );
    }
  }

  /// Draws the bands behind the exons of [layout] about the line at [mid],
  /// the point [offset] base pairs from the 5′ end at screen x [x], on a
  /// canvas [width] wide: flat, a part of an exon square where it meets the
  /// next part of the same exon and round at the exon's ends; [sink] of the
  /// way sunk to nothing behind the DNA.
  static void bands(
    Canvas canvas,
    ZoomInks inks,
    GeneLayout layout, {
    required double Function(double offset) x,
    required double mid,
    required double width,
    double sink = 0,
  }) {
    final double kept = 1 - sink;
    if (kept <= 0) {
      return;
    }
    double clampX(double at) => at.clamp(-8.0, width + 8);
    final List<GenePiece> pieces = layout.pieces;
    for (int i = 0; i < pieces.length; i++) {
      final GenePiece piece = pieces[i];
      if (piece.kind == GenePieceKind.intron) {
        continue;
      }
      final double a = x(piece.start);
      final double b = x(piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > width + 8) {
        continue;
      }
      final double half =
          (piece.kind == GenePieceKind.cds ? coding : untranslated) * kept;
      if (half < 0.05) {
        continue;
      }
      final double centre = (left + right) / 2;
      final double reach = math.max((right - left) / 2, 0.5);
      final Rect block = Rect.fromLTRB(
        clampX(centre - reach),
        mid - half,
        clampX(centre + reach),
        mid + half,
      );
      // Round where the exon ends, square where its next part goes on: the
      // part before it and the part after it, 5′ to 3′, laid on screen the
      // way the gene faces.
      bool joins(int j) =>
          j >= 0 &&
          j < pieces.length &&
          pieces[j].kind != GenePieceKind.intron;
      final bool before = joins(i - 1);
      final bool after = joins(i + 1);
      final bool forward = a <= b;
      final bool squareLeft = forward ? before : after;
      final bool squareRight = forward ? after : before;
      final Radius round = Radius.circular(
        math.min(2, math.min(block.width / 2, half)),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          block,
          topLeft: squareLeft ? Radius.zero : round,
          bottomLeft: squareLeft ? Radius.zero : round,
          topRight: squareRight ? Radius.zero : round,
          bottomRight: squareRight ? Radius.zero : round,
        ),
        Paint()..color = band(inks, piece.kind),
      );
    }
  }
}
