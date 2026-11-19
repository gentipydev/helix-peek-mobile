import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/helix/helix_geometry.dart';
import '../../domain/chromatin_layout.dart';
import '../zoom_inks.dart';
import 'chromatin_beads.dart';
import 'gene_strand.dart';
import 'nucleosome_art.dart';

/// The DNA's grooves as the fibre draws them: its two backbones as fine
/// ridges along its lit body where they face the reader, at the angle the
/// helix's painter gives them and turning with it, so that where the DNA's
/// skin clears onto the helix ([DnaScene]) the ridges are the painter's own
/// backbones (the user's choice of 2026-11-18: the DNA a body with its
/// grooves all the way down, never two loose strands).
@immutable
final class DnaGrooves {
  const DnaGrooves({
    required this.shown,
    required this.turn,
    required this.anchor,
    this.cleared = 0,
  });

  /// How far the ridges show over the DNA's body: 0 a plain lit tube, 1 its
  /// backbones whole.
  final double shown;

  /// How far the helix has turned, in turns, as its painter is drawn.
  final double turn;

  /// How many of the record's first bases the helix carries: its painter
  /// lays them 3′ first, its first rung at [anchor] base pairs from the
  /// gene's 5′ end.
  final double anchor;

  /// How far the DNA's skin over those bases has cleared onto the helix,
  /// from 0 to 1.
  final double cleared;

  /// The helix's painter's perspective: its focal length, in radii.
  static const double focal = 12;

  /// A ridge's width on screen, in pixels: the least the painter draws a
  /// backbone at, short of the view it draws the helix whole in.
  static const double strand = 1.4;

  /// Over how many base pairs past the helix's last base the DNA's skin
  /// closes up again, as it clears: the DNA going on past the helix as a
  /// rope, not cut off.
  static const double lip = 3;

  /// The angle round the duplex of its first backbone at [offset] base
  /// pairs from the gene's 5′ end, or of its second, a minor groove on: as
  /// the painter lays them, the base at [offset] lying (anchor − offset) /
  /// anchor of the way along its model, turned [turn].
  double angleAt(double offset, {bool second = false}) =>
      2 *
          math.pi *
          ((offset - anchor) / HelixModel.basePairsPerTurn + turn) +
      (second ? HelixModel.grooveOffset : 0);

  /// How far from its axis a backbone at [angle] lies across a duplex
  /// [thick] pixels thick, down the screen for a duplex laid left to
  /// right, in the painter's perspective; and whether it faces the reader.
  static (double, bool) across(double angle, double thick) {
    final double s = math.sin(angle);
    return (thick / 2 * math.cos(angle) * focal / (focal + s), s < 0);
  }

  /// How much of the DNA's body shows at [offset]: over the helix's bases,
  /// what has not cleared, closing up again over the [lip] past them.
  double skinAt(double offset) {
    if (offset < 0 || cleared <= 0 || offset >= anchor + lip) {
      return 1;
    }
    if (offset < anchor) {
      return 1 - cleared;
    }
    return 1 - cleared * (1 - (offset - anchor) / lip);
  }

  /// How wide the ridges are at [offset], a share of [strand]: over the
  /// helix's bases they thin away under the painter's own backbones once
  /// it shows nearly whole, which cover them exactly.
  double strandsAt(double offset) => offset >= 0 && offset < anchor
      ? 1 - _smooth((cleared - 0.65) / 0.35)
      : 1;
}

double _smooth(double x) {
  final double t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A gene's DNA as chromatin, drawn the same from the gene's stop down to
/// its first bases: a line along the fibre, and on it the nucleosomes
/// [ChromatinBeads] picks, each a histone core with its DNA wound round it
/// ([ChromatinLayout.coilAt]), never smaller than [ChromatinBeads.least]:
/// larger than life where the gene is far, its own size close in.
///
/// The gene's scene draws it on the step that reaches the gene and the
/// DNA's from the gene's stop on, so the stop is one picture from either
/// side. Where a nucleosome is drawn, its DNA leaves the line to wind round
/// its core and comes back to it, and the line is not drawn between: a
/// nucleosome coming up takes over the line there as it does, so the DNA
/// is never drawn twice. As the fibre packs, the line between the cores is
/// drawn in.
abstract final class ChromatinFibre {
  static const ChromatinLayout _layout = ChromatinLayout();

  /// How many stretches a nucleosome's DNA is laid in at the least, and at
  /// the most where its strands do not show.
  static const int _samples = 12;
  static const int _most = 160;

  /// How much wider than the DNA the ground is laid under it where it
  /// crosses a core, in pixels.
  static const double casing = 1.2;

  /// How much larger than life a nucleosome is drawn, where a base pair's
  /// length is [perBase] pixels: its core no smaller than
  /// [ChromatinBeads.least] across from its middle, or [grown] of that where
  /// there is not yet room for it.
  static double magnified(double perBase, [double grown = 1]) => math.max(
    1,
    ChromatinBeads.least * grown / (NucleosomeArt.radius * perBase),
  );

  /// Draws the DNA on the line at [mid], on a canvas [width] wide: the place
  /// [along] base pairs' lengths along the fibre from the gene's 5′ end at
  /// screen x [x] (a base pair's length [perBase] pixels), [packed] of the
  /// way packed, [thick] pixels thick with its [grooves] showing, if any.
  /// [colourAt] is the DNA's colour at a point, in base pairs from the
  /// gene's 5′ end, changing only at [marks]; [shownOf] how much of a
  /// nucleosome shows, by its index, none below [depth] looked at; [grown]
  /// how far grown to its least size each is ([magnified]).
  static void paint(
    Canvas canvas,
    ZoomInks inks, {
    required double Function(double along) x,
    required double perBase,
    required double mid,
    required double width,
    required double packed,
    required double thick,
    required List<double> marks,
    required Color Function(double offset) colourAt,
    required int depth,
    required double Function(int index) shownOf,
    DnaGrooves? grooves,
    double grown = 1,
  }) {
    final double m = magnified(perBase, grown);
    final double scale = m * perBase;
    final double reach = ChromatinLayout.reach * m;
    final double origin = x(0);
    final List<double> sorted = <double>[...marks]..sort();
    double alongOf(double screenX) => (screenX - origin) / perBase;
    final double lineFrom = _layout.offsetAt(alongOf(-thick - 8), packed);
    final double lineTo = _layout.offsetAt(alongOf(width + thick + 8), packed);

    // The nucleosomes drawn: each one's core along the fibre, where its DNA
    // leaves the line and comes back to it, in base pairs, and how much of
    // it shows.
    final List<(double, double, double, double)> beads =
        <(double, double, double, double)>[];
    for (final int index in ChromatinBeads.within(
      _layout.offsetAt(alongOf(0) - reach, packed) - ChromatinLayout.wrapped,
      _layout.offsetAt(alongOf(width) + reach, packed) + ChromatinLayout.wrapped,
      depth,
    )) {
      final double shown = shownOf(index);
      if (shown <= 0.002) {
        continue;
      }
      final double core = _layout.coreAt(ChromatinBeads.startOf(index), packed);
      final double left = x(core - reach);
      final double right = x(core + reach);
      if (right < -thick || left > width + thick) {
        continue;
      }
      beads.add((
        core,
        _layout.offsetAt(core - reach, packed),
        _layout.offsetAt(core + reach, packed),
        shown,
      ));
    }

    // The line: straight along the fibre, broken at each change of colour,
    // where the fibre's packing bends its scale, and where a nucleosome takes
    // it over, there drawn at what the nucleosome leaves of it. It runs half
    // a pixel on under the nucleosome's DNA, so the two meet with no seam.
    final double overlap = 0.5 / perBase;
    final List<double> cuts = <double>[
      lineFrom,
      lineTo,
      for (final double mark in marks)
        if (mark > lineFrom && mark < lineTo) mark,
      for (final (double _, double a, double b, double _) in beads) ...<double>[
        if (a + overlap > lineFrom && a + overlap < lineTo) a + overlap,
        if (b - overlap > lineFrom && b - overlap < lineTo) b - overlap,
      ],
      if (packed > 0)
        for (final (double start, double end) in _layout.nucleosomesWithin(
          lineFrom,
          lineTo,
        )) ...<double>[
          if (start > lineFrom && start < lineTo) start,
          if (end > lineFrom && end < lineTo) end,
        ],
    ]..sort();
    final _Strokes line = _Strokes(grooves);
    for (int i = 0; i + 1 < cuts.length; i++) {
      final double a = cuts[i];
      final double b = cuts[i + 1];
      if (b - a < 1e-9) {
        continue;
      }
      final double middle = (a + b) / 2;
      double left = 1;
      for (final (double _, double from, double to, double shown) in beads) {
        if (middle > from + overlap && middle < to - overlap) {
          left = 1 - shown;
          break;
        }
      }
      if (left <= 0.002) {
        continue;
      }
      final Color colour = colourAt(middle);
      if (colour.a <= 0.002) {
        continue;
      }
      line.add(
        colour.withValues(alpha: colour.a * left),
        Offset(x(_layout.axisAt(a, packed)), mid),
        Offset(x(_layout.axisAt(b, packed)), mid),
        a,
        b,
      );
    }
    line.paint(canvas, inks, thick);

    // The nucleosomes, those that show as much together on one layer: as
    // they come up with the gene, or a depth of them at a time.
    final double turnsRadius = ChromatinLayout.radius * scale;
    final double around = 1.6 * turnsRadius + thick;
    final List<(double, double, double, double)> left = beads.toList();
    while (left.isNotEmpty) {
      final double shown = left.first.$4;
      final List<(double, double, double, double)> together =
          <(double, double, double, double)>[
            for (final (double, double, double, double) bead in left)
              if (bead.$4 == shown) bead,
          ];
      left.removeWhere(
        ((double, double, double, double) bead) => bead.$4 == shown,
      );
      final bool fading = shown < 0.995;
      if (fading) {
        final double xs = x(together.first.$1);
        final double xe = x(together.last.$1);
        canvas.saveLayer(
          Rect.fromLTRB(
            math.min(xs, xe) - around,
            mid - around,
            math.max(xs, xe) + around,
            mid + around,
          ),
          Paint()..color = Color.fromRGBO(0, 0, 0, shown),
        );
      }
      // One coming up grows out of the line as it does, from a little bead
      // to its size: faint and whole, a grey disc on the ground reads as a
      // dark one.
      final double grow = 0.4 + 0.6 * shown;
      for (final (double core, double from, double to, double _) in together) {
        _nucleosome(
          canvas,
          inks,
          centre: Offset(x(core), mid),
          scale: scale,
          grow: grow,
          from: from,
          to: to,
          perBase: perBase,
          thick: thick,
          grooves: grooves,
          colourAt: colourAt,
          marks: sorted,
        );
      }
      if (fading) {
        canvas.restore();
      }
    }
  }

  /// Draws one nucleosome about [centre], a base pair's length [scale]
  /// pixels round its core, [grow] of its size: the DNA behind the core, the
  /// core, the DNA in front, its DNA the genome's [from] to [to] base pairs.
  static void _nucleosome(
    Canvas canvas,
    ZoomInks inks, {
    required Offset centre,
    required double scale,
    required double grow,
    required double from,
    required double to,
    required double perBase,
    required double thick,
    required DnaGrooves? grooves,
    required Color Function(double offset) colourAt,
    required List<double> marks,
  }) {
    final _Strokes behind = _Strokes(grooves);
    final _Strokes inFront = _Strokes(grooves);
    Offset screen(FibrePoint p) =>
        centre + Offset(p.along * scale * grow, p.across * scale * grow);
    // About two pixels a stretch of its way round, and fine enough to
    // follow its grooves where they show.
    int samples = (_length * scale / 2).round().clamp(_samples, _most);
    if (grooves != null && grooves.shown > 0) {
      samples = math.max(samples, ((to - from) * perBase / 1.2).ceil());
    }
    FibrePoint last = ChromatinLayout.coilAt(0);
    for (int i = 0; i < samples; i++) {
      final double u = (i + 1) / samples;
      final FibrePoint p = ChromatinLayout.coilAt(u);
      final double a = from + (to - from) * i / samples;
      final double b = from + (to - from) * u;
      final Color colour = _majority(a, b, marks, colourAt);
      if (colour.a > 0.002) {
        final FibrePoint half = ChromatinLayout.coilAt((i + 0.5) / samples);
        (half.depth < 0 ? behind : inFront).add(
          colour,
          screen(last),
          screen(p),
          a,
          b,
        );
      }
      last = p;
    }
    // The core fills its DNA's turns, as thick as the DNA is drawn.
    final double turnsRadius = ChromatinLayout.radius * scale * grow;
    final double coreRadius = math.max(
      turnsRadius - thick / 2,
      0.6 * turnsRadius,
    );
    behind.paint(canvas, inks, thick, shaded: true);
    NucleosomeArt.paint(canvas, centre, coreRadius, inks);
    // Edged in the ground where it crosses the core, so it reads on it.
    inFront.paint(canvas, inks, thick, casing: casing);
  }

  /// How long a nucleosome's DNA is from where it leaves the line to where
  /// it comes back, in base pairs' lengths, near enough.
  static const double _length = 160;

  /// The colour most of the DNA from [from] to [to] is drawn in, its colour
  /// changing only at [marks] (in order): a stretch of a nucleosome's DNA
  /// drawn far larger than life stands for thousands of base pairs, and
  /// the colour at its middle alone would light a stray exon there, a
  /// different one each frame as the gene opens out.
  static Color _majority(
    double from,
    double to,
    List<double> marks,
    Color Function(double offset) colourAt,
  ) {
    final double a = math.min(from, to);
    final double b = math.max(from, to);
    // The first mark past a.
    int low = 0;
    int high = marks.length;
    while (low < high) {
      final int middle = (low + high) >> 1;
      if (marks[middle] <= a) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low >= marks.length || marks[low] >= b) {
      return colourAt((a + b) / 2);
    }
    final Map<int, double> lengths = <int, double>{};
    final Map<int, Color> colours = <int, Color>{};
    double start = a;
    for (int i = low; start < b; i++) {
      final double stop = i < marks.length && marks[i] < b ? marks[i] : b;
      if (stop > start) {
        final Color colour = colourAt((start + stop) / 2);
        final int key = colour.toARGB32();
        colours[key] = colour;
        lengths[key] = (lengths[key] ?? 0) + stop - start;
      }
      start = stop;
    }
    int best = lengths.keys.first;
    for (final MapEntry<int, double> entry in lengths.entries) {
      if (entry.value > lengths[best]!) {
        best = entry.key;
      }
    }
    return colours[best]!;
  }
}

/// The DNA's strokes by colour, laid as it runs: a run of one colour is one
/// stroke, so the DNA turns without seams; its body always drawn, a lit
/// tube, and over it, where its [grooves] show, its two backbones as ridges
/// where they face the reader. Colours are told apart as they are drawn, to
/// the 8 bits of a pixel, so two that differ by a rounding are one stroke.
final class _Strokes {
  _Strokes(this.grooves);

  final DnaGrooves? grooves;

  final Map<int, Path> _body = <int, Path>{};
  final Map<int, Color> _inks = <int, Color>{};
  final Map<int, Offset> _ends = <int, Offset>{};

  /// Each stretch laid: its colour, its ends on screen and in base pairs.
  final List<(Color, Offset, Offset, double, double)> _laid =
      <(Color, Offset, Offset, double, double)>[];

  /// The stretches whose skin closes up along them, past the helix's last
  /// base: their colour, their ends on screen, and their skin at each end.
  final List<(Color, Offset, Offset, double, double)> _closing =
      <(Color, Offset, Offset, double, double)>[];

  void add(Color colour, Offset a, Offset b, double from, double to) {
    _laid.add((colour, a, b, from, to));
    final DnaGrooves? grooves = this.grooves;
    if (grooves != null) {
      final double first = grooves.skinAt(from);
      final double last = grooves.skinAt(to);
      if ((first - last).abs() > 1e-6) {
        _closing.add((colour, a, b, first, last));
        return;
      }
    }
    // Its body, less what has cleared of its skin over the helix's bases.
    final double skin = grooves?.skinAt((from + to) / 2) ?? 1;
    final Color body = skin < 1
        ? colour.withValues(alpha: colour.a * skin)
        : colour;
    if (body.a <= 0.002) {
      return;
    }
    final int key = body.toARGB32();
    _inks.putIfAbsent(key, () => body);
    final Path path = _body[key] ??= Path();
    final Offset? end = _ends[key];
    if (end == null || (end - a).distanceSquared > 0.01) {
      path.moveTo(a.dx, a.dy);
    }
    path.lineTo(b.dx, b.dy);
    _ends[key] = b;
  }

  /// Draws the DNA [thick] pixels thick: in shade behind a core, on a
  /// [casing] of the ground that much wider where it crosses one.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double thick, {
    bool shaded = false,
    double casing = 0,
  }) {
    Color shade(Color c, double by) =>
        Color.lerp(c, inks.ground, by)!.withValues(alpha: c.a);
    if (casing > 0) {
      for (final MapEntry<int, Path> body in _body.entries) {
        canvas.drawPath(
          body.value,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thick + casing
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round
            ..color = inks.ground.withValues(alpha: 0.8 * _inks[body.key]!.a),
        );
      }
    }
    for (final MapEntry<int, Path> body in _body.entries) {
      GeneStrand.tube(
        canvas,
        body.value,
        shade(_inks[body.key]!, shaded ? 0.4 : 0),
        thick,
        inks,
      );
    }
    // The skin closing up past the helix: the same lit tube, its body and
    // its light graded along it.
    final double lit = ((thick - 2.5) / 3).clamp(0.0, 1.0);
    for (final (Color colour, Offset a, Offset b, double first, double last)
        in _closing) {
      final Color body = shade(colour, shaded ? 0.4 : 0);
      Color at(double skin) => body.withValues(alpha: body.a * skin);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick
          ..strokeCap = StrokeCap.butt
          ..shader = ui.Gradient.linear(a, b, <Color>[at(first), at(last)]),
      );
      if (lit > 0) {
        final Offset up = Offset(0, -0.2 * thick);
        Color glint(double skin) => Color.lerp(
          body,
          inks.text,
          0.45,
        )!.withValues(alpha: body.a * skin * 0.55 * lit);
        canvas.drawLine(
          a + up,
          b + up,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.35 * thick
            ..strokeCap = StrokeCap.butt
            ..shader = ui.Gradient.linear(a + up, b + up, <Color>[
              glint(first),
              glint(last),
            ]),
        );
      }
    }
    final DnaGrooves? grooves = this.grooves;
    if (grooves != null && grooves.shown > 0) {
      _ridges(canvas, inks, thick, grooves, shaded);
    }
  }

  /// The two backbones as ridges over the body, where they face the reader:
  /// each a stroke for as long as it stays in front, in one colour and one
  /// width, sampled no further apart than two pixels or 0.3 of a radian of
  /// its turn; thinning away where a nucleosome's DNA turns more tightly than
  /// the duplex is thick, where offset points would fold over each other.
  void _ridges(
    Canvas canvas,
    ZoomInks inks,
    double thick,
    DnaGrooves grooves,
    bool shaded,
  ) {
    final Map<(int, int), Path> paths = <(int, int), Path>{};
    final Map<(int, int), (Color, double)> styles =
        <(int, int), (Color, double)>{};
    final double r = thick / 2;
    const double perTurn = 2 * math.pi / HelixModel.basePairsPerTurn;
    for (final bool second in <bool>[false, true]) {
      Offset? last;
      Path? open;
      (int, int)? openKey;
      Offset? stretchEnd;
      Offset? lastWay;
      for (final (Color colour, Offset a, Offset b, double from, double to)
          in _laid) {
        final Offset along = b - a;
        final double length = along.distance;
        if (length < 1e-6) {
          continue;
        }
        final Offset way = along / length;
        final bool joined =
            stretchEnd != null && (stretchEnd - a).distanceSquared <= 0.01;
        // How tightly the DNA turns here: its radius of curvature, from the
        // turn between this stretch and the one before it.
        double tight = 1;
        if (joined && lastWay != null) {
          final double bend = math
              .atan2(
                lastWay.dx * way.dy - lastWay.dy * way.dx,
                lastWay.dx * way.dx + lastWay.dy * way.dy,
              )
              .abs();
          if (bend > 1e-9) {
            tight = _smooth((length / bend - r / 2) / r);
          }
        }
        if (!joined) {
          last = null;
          open = null;
        }
        stretchEnd = b;
        lastWay = way;
        final Offset normal = Offset(-way.dy, way.dx);
        // Its colour lifted toward the light, laid over the opaque body as
        // far as the grooves show; as faint as the DNA there is, whatever
        // has cleared of its skin.
        final Color opaque = colour.withValues(alpha: 1);
        Color ink = Color.lerp(
          opaque,
          GeneStrand.ridge(opaque, inks),
          grooves.shown,
        )!;
        if (shaded) {
          ink = Color.lerp(ink, inks.ground, 0.4)!;
        }
        ink = ink.withValues(alpha: colour.a);
        final int steps = math.max(
          1,
          math.max(
            (length / 2).ceil(),
            ((to - from).abs() * perTurn / 0.3).ceil(),
          ),
        );
        for (int k = 0; k <= steps; k++) {
          final double t = k / steps;
          final double offset = from + (to - from) * t;
          final (double out, bool front) = DnaGrooves.across(
            grooves.angleAt(offset, second: second),
            thick,
          );
          final Offset p = a + along * t + normal * out;
          final double wide =
              DnaGrooves.strand * grooves.strandsAt(offset) * tight;
          if (!front || wide < 0.05 || ink.a <= 0.002) {
            last = p;
            open = null;
            continue;
          }
          final (int, int) key = (ink.toARGB32(), (wide * 32).round());
          if (last == null) {
            last = p;
            continue;
          }
          if (open == null || openKey != key) {
            open = paths[key] ??= Path();
            // The width it was first drawn at: a whole ridge exactly as
            // wide as the painter's backbones, which come to cover it.
            styles[key] ??= (ink, wide);
            open.moveTo(last.dx, last.dy);
            openKey = key;
          }
          open.lineTo(p.dx, p.dy);
          last = p;
        }
      }
    }
    for (final MapEntry<(int, int), Path> ridge in paths.entries) {
      final (Color ink, double wide) = styles[ridge.key]!;
      canvas.drawPath(
        ridge.value,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = wide
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink,
      );
    }
  }
}
