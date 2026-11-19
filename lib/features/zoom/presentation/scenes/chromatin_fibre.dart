import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/helix/helix_geometry.dart';
import '../../domain/chromatin_layout.dart';
import '../zoom_inks.dart';
import 'chromatin_beads.dart';
import 'gene_strand.dart';
import 'nucleosome_art.dart';

/// The DNA's grooves as the fibre draws them: its two backbones as fine
/// ridges along its lit body where they face the reader, at the angle the
/// helix's painter gives them and turning with it (the user's choice of
/// 2026-11-18: the DNA a body with its grooves, not a scribble). As the
/// view nears the helix the body clears, all along the DNA ([cleared]), and
/// the DNA is an open double helix, both backbones showing, the far one in
/// shade, wound round each core (the user's ask of 2026-11-19: to see the
/// helix round the nucleosome); over the record's first bases the helix's
/// painter comes up under it ([DnaScene]), its backbones where they are.
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

  /// How far the DNA's skin has cleared, all along it, from 0 to 1: over
  /// the record's first bases onto the helix.
  final double cleared;

  /// The helix's painter's perspective: its focal length, in radii.
  static const double focal = 12;

  /// A ridge's width on screen, in pixels: the least the painter draws a
  /// backbone at, short of the view it draws the helix whole in.
  static const double strand = 1.4;

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

  /// How much of the DNA's body shows: what has not cleared.
  double get skin => 1 - cleared;

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
    // Where its backbones lie round it: a frame at each sample, carried
    // along its way round the core.
    final List<_Frame>? frames = grooves != null && grooves.shown > 0
        ? _coilFrames(samples)
        : null;
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
          frames?[i] ?? _straight,
          frames?[i + 1] ?? _straight,
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

  /// The frames a nucleosome's DNA carries its backbones in, at each of
  /// [samples] + 1 points along its way round the core: carried with as
  /// little turn as can be (each the last reflected twice, Wang et al.
  /// 2008), from the line's own where it leaves it, and evened out along the
  /// way so that it is the line's again where it comes back to it: its
  /// backbones go round the core and on along the line without a break.
  static List<_Frame> _coilFrames(int samples) =>
      _frames[samples] ??= () {
        _Vec at(double u) {
          final FibrePoint p = ChromatinLayout.coilAt(u);
          return (p.along, p.across, p.depth);
        }

        _Vec way(double u) {
          const double h = 1e-4;
          return _unit(_minus(at(u + h), at(u - h)));
        }

        final List<_Vec> points = <_Vec>[
          for (int i = 0; i <= samples; i++) at(i / samples),
        ];
        final List<_Vec> ways = <_Vec>[
          for (int i = 0; i <= samples; i++) way(i / samples),
        ];
        final List<_Vec> normals = <_Vec>[(0, 1, 0)];
        final List<double> lengths = <double>[0];
        for (int i = 0; i < samples; i++) {
          final _Vec v1 = _minus(points[i + 1], points[i]);
          final double c1 = _dot(v1, v1);
          final _Vec r = normals[i];
          final _Vec rL = _minus(r, _times(v1, 2 / c1 * _dot(v1, r)));
          final _Vec tL = _minus(ways[i], _times(v1, 2 / c1 * _dot(v1, ways[i])));
          final _Vec v2 = _minus(ways[i + 1], tL);
          final double c2 = _dot(v2, v2);
          normals.add(
            c2 < 1e-12
                ? rL
                : _unit(_minus(rL, _times(v2, 2 / c2 * _dot(v2, rL)))),
          );
          lengths.add(lengths[i] + math.sqrt(c1));
        }
        // The turn the frame has taken by the end, given back evenly along
        // the way.
        final _Vec end = ways[samples];
        final _Vec home = _unit(
          _minus((0, 1, 0), _times(end, _dot((0, 1, 0), end))),
        );
        final double turned = math.atan2(
          _dot(end, _cross(normals[samples], home)),
          _dot(normals[samples], home),
        );
        return <_Frame>[
          for (int i = 0; i <= samples; i++)
            () {
              final _Vec n = _turn(
                normals[i],
                ways[i],
                turned * lengths[i] / lengths[samples],
              );
              final _Vec q = _cross(n, ways[i]);
              return _Frame(n.$1, n.$2, n.$3, q.$1, q.$2, q.$3);
            }(),
        ];
      }();

  static final Map<int, List<_Frame>> _frames = <int, List<_Frame>>{};

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

/// A direction, along the fibre, across it down the screen and toward the
/// reader.
typedef _Vec = (double, double, double);

/// Where the DNA's backbones lie round it at a point: the way they are at
/// angle 0 (n), and at a quarter turn on (b).
@immutable
final class _Frame {
  const _Frame(this.nx, this.ny, this.nz, this.bx, this.by, this.bz);

  final double nx;
  final double ny;
  final double nz;
  final double bx;
  final double by;
  final double bz;
}

/// The line's own frame, as the helix's painter lays it: a backbone at
/// angle 0 straight down the screen, at a quarter turn away from the reader.
const _Frame _straight = _Frame(0, 1, 0, 0, 0, -1);

/// A stretch of the DNA as laid: its colour, its ends on screen and in base
/// pairs, and the frames its backbones lie in at its ends.
@immutable
final class _Stretch {
  const _Stretch(
    this.colour,
    this.a,
    this.b,
    this.from,
    this.to,
    this.first,
    this.last,
  );

  final Color colour;
  final Offset a;
  final Offset b;
  final double from;
  final double to;
  final _Frame first;
  final _Frame last;
}

_Vec _minus(_Vec a, _Vec b) => (a.$1 - b.$1, a.$2 - b.$2, a.$3 - b.$3);
_Vec _times(_Vec a, double k) => (a.$1 * k, a.$2 * k, a.$3 * k);
double _dot(_Vec a, _Vec b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;
_Vec _cross(_Vec a, _Vec b) => (
  a.$2 * b.$3 - a.$3 * b.$2,
  a.$3 * b.$1 - a.$1 * b.$3,
  a.$1 * b.$2 - a.$2 * b.$1,
);
_Vec _unit(_Vec a) {
  final double n = math.sqrt(_dot(a, a));
  return n < 1e-12 ? a : _times(a, 1 / n);
}

/// [v] turned [angle] about the unit [axis].
_Vec _turn(_Vec v, _Vec axis, double angle) {
  final double c = math.cos(angle);
  final double s = math.sin(angle);
  final _Vec k = _cross(axis, v);
  final double along = _dot(axis, v) * (1 - c);
  return (
    v.$1 * c + k.$1 * s + axis.$1 * along,
    v.$2 * c + k.$2 * s + axis.$2 * along,
    v.$3 * c + k.$3 * s + axis.$3 * along,
  );
}

/// The DNA's strokes by colour, laid as it runs: a run of one colour is one
/// stroke, so the DNA turns without seams; its body a lit tube, and with
/// it, where its [grooves] show, its two backbones: the near halves as
/// ridges over the body, the far halves under it, showing as the body
/// clears. Colours are told apart as they are drawn, to the 8 bits of a
/// pixel, so two that differ by a rounding are one stroke.
final class _Strokes {
  _Strokes(this.grooves);

  final DnaGrooves? grooves;

  final Map<int, Path> _body = <int, Path>{};
  final Map<int, Color> _inks = <int, Color>{};
  final Map<int, Offset> _ends = <int, Offset>{};

  /// Each stretch laid.
  final List<_Stretch> _laid = <_Stretch>[];

  void add(
    Color colour,
    Offset a,
    Offset b,
    double from,
    double to, [
    _Frame first = _straight,
    _Frame last = _straight,
  ]) {
    _laid.add(_Stretch(colour, a, b, from, to, first, last));
    // Its body, less what has cleared of its skin.
    final double skin = grooves?.skin ?? 1;
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
  /// [casing] of the ground that much wider where it crosses one; its far
  /// backbones under its body, its near ones over it.
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
    final DnaGrooves? grooves = this.grooves;
    final bool grooved = grooves != null && grooves.shown > 0;
    if (grooved) {
      _backbones(canvas, inks, thick, grooves, shaded, near: false);
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
    if (grooved) {
      _backbones(canvas, inks, thick, grooves, shaded, near: true);
    }
  }

  /// The two backbones' halves on the [near] side of the duplex, or its far
  /// side: each a stroke for as long as it stays on that side, in one colour
  /// and one width, sampled no further apart than two pixels or 0.3 of a
  /// radian of its turn, laid round the duplex in the frames it was laid
  /// with, as the helix's painter lays its own, in its perspective.
  void _backbones(
    Canvas canvas,
    ZoomInks inks,
    double thick,
    DnaGrooves grooves,
    bool shaded, {
    required bool near,
  }) {
    // Each stroke by its colour and its width, a 32nd of a pixel at a time,
    // in one number.
    final Map<int, Path> paths = <int, Path>{};
    final Map<int, Color> colours = <int, Color>{};
    final Map<int, double> widths = <int, double>{};
    final double r = thick / 2;
    const double perTurn = 2 * math.pi / HelixModel.basePairsPerTurn;
    const double focal = DnaGrooves.focal;
    for (final bool second in <bool>[false, true]) {
      double lastX = 0;
      double lastY = 0;
      bool hasLast = false;
      Path? open;
      int openKey = -1;
      Offset? stretchEnd;
      for (final _Stretch stretch in _laid) {
        final Offset a = stretch.a;
        final double dx = stretch.b.dx - a.dx;
        final double dy = stretch.b.dy - a.dy;
        final double length = math.sqrt(dx * dx + dy * dy);
        if (length < 1e-6) {
          continue;
        }
        if (stretchEnd == null || (stretchEnd - a).distanceSquared > 0.01) {
          hasLast = false;
          open = null;
        }
        stretchEnd = stretch.b;
        // Its colour lifted toward the light, laid over the opaque body as
        // far as the grooves show, the far side in shade as the helix's
        // painter shades its own by depth; as faint as the DNA there is,
        // whatever has cleared of its skin.
        final Color colour = stretch.colour;
        final Color opaque = colour.withValues(alpha: 1);
        final Color ink = Color.lerp(
          Color.lerp(opaque, GeneStrand.ridge(opaque, inks), grooves.shown)!,
          inks.ground,
          near ? (shaded ? 0.4 : 0) : (shaded ? 0.7 : 0.45),
        )!.withValues(alpha: colour.a);
        if (ink.a <= 0.002) {
          continue;
        }
        final int argb = ink.toARGB32();
        final double from = stretch.from;
        final double to = stretch.to;
        final _Frame f = stretch.first;
        final _Frame g = stretch.last;
        final bool turning = !identical(f, g);
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
          // The frame here, between the stretch's two.
          double nx = f.nx;
          double ny = f.ny;
          double nz = f.nz;
          double bx = f.bx;
          double by = f.by;
          double bz = f.bz;
          if (turning && t > 0) {
            nx += (g.nx - f.nx) * t;
            ny += (g.ny - f.ny) * t;
            nz += (g.nz - f.nz) * t;
            bx += (g.bx - f.bx) * t;
            by += (g.by - f.by) * t;
            bz += (g.bz - f.bz) * t;
            final double n = math.sqrt(nx * nx + ny * ny + nz * nz);
            final double q = math.sqrt(bx * bx + by * by + bz * bz);
            nx /= n;
            ny /= n;
            nz /= n;
            bx /= q;
            by /= q;
            bz /= q;
          }
          final double angle = grooves.angleAt(offset, second: second);
          final double c = math.cos(angle);
          final double s = math.sin(angle);
          final double z = r * (c * nz + s * bz);
          // The painter's perspective: nearer is larger.
          final double scale = r <= 0 ? 1 : focal / (focal - z / r);
          final double x = a.dx + dx * t + r * (c * nx + s * bx) * scale;
          final double y = a.dy + dy * t + r * (c * ny + s * by) * scale;
          final double wide = DnaGrooves.strand * grooves.strandsAt(offset);
          if ((z > 0) != near || wide < 0.05) {
            lastX = x;
            lastY = y;
            hasLast = true;
            open = null;
            continue;
          }
          final int key = argb * 64 + (wide * 32).round();
          if (!hasLast) {
            lastX = x;
            lastY = y;
            hasLast = true;
            continue;
          }
          if (open == null || openKey != key) {
            open = paths[key] ??= Path();
            colours[key] ??= ink;
            // The width it was first drawn at: a whole backbone exactly as
            // wide as the painter's, which come to cover it.
            widths[key] ??= wide;
            open.moveTo(lastX, lastY);
            openKey = key;
          }
          open.lineTo(x, y);
          lastX = x;
          lastY = y;
        }
      }
    }
    for (final MapEntry<int, Path> backbone in paths.entries) {
      canvas.drawPath(
        backbone.value,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = widths[backbone.key]!
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colours[backbone.key]!,
      );
    }
  }
}
