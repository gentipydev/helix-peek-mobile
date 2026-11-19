import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/chromatin_layout.dart';
import '../../domain/dna_dive.dart';
import '../../domain/gene_layout.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'band_scene.dart';
import 'body_scene.dart';
import 'chromatin_beads.dart';
import 'chromatin_fibre.dart';
import 'gene_strand.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene as a stretch of chromatin, still: its DNA a line beaded with its
/// nucleosomes, each its DNA wound round a histone core, larger than life
/// ([ChromatinFibre]; the user's choice of 2026-10-16, to see them), going
/// on either side of it, and its exons as a genome browser draws a
/// transcript, a quiet band behind the chromatin for each, coding parts tall
/// and untranslated ends short, the DNA along them in the mark's two
/// strengths ([GeneStrand]; the user's choice of 2026-11-18: the bands never
/// cover a nucleosome), every part at its real length along the span MANE
/// gives it; a ruler from its 5′ end
/// and a name where transcription starts (the user's choice of
/// 2026-10-16: a snapshot of the gene, nothing reading it, after a still of
/// it being read that read as an animation laid out in space; its bent
/// arrow went the same day, heavy beside the name's line).
///
/// It reads 5′ to 3′, left to right, as the walk does, from the moment it
/// appears: on the band's strip the gene is a mark with nothing inside it to
/// turn, and turned over about its middle a mark is the same mark, so a gene
/// on the reverse strand is drawn facing the walk's way without a turn that
/// would swing its ends across the view.
///
/// It opens out of that mark as the band's map gives way, and its ruler,
/// its exons' numbers, its start and its 3′ end come up as it is reached. On
/// the way to the DNA those go first, and the exons give way as the view
/// closes in on its 5′ end, gone before the double helix comes up there.
final class GeneScene extends ZoomScene {
  GeneScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.gene;

  double get _width => subject.depth.widthOf(stop);

  bool get _reverse => subject.track.strand < 0;

  /// Which way the gene lies on screen: 1 the genome's way, -1 turned over,
  /// as a gene on the reverse strand is to read 5′ to 3′.
  double get _facing => _reverse ? -1 : 1;

  /// A genome position in the scene's units, from the gene's middle, the
  /// genome's way round.
  double unitOf(double position) => (position - subject.geneMiddle) / _width;

  /// The point [offset] base pairs into the gene from its 5′ end, the
  /// genome's way round.
  double unitAlong(double offset) => unitOf(subject.genomeAt(offset));

  // The DNA's view lies [ZoomSubject.dnaView] base pairs of the genome
  // along from the gene's 5′ end: the DNA counts the genome's base pairs,
  // where this scene lays the record's along MANE's span, a little shorter
  // for a few genes, so the two meet exactly at the 5′ end.
  @override
  Offset get portal => Offset(
    _facing *
        unitOf(subject.genomeAt(0) + (_reverse ? -1 : 1) * subject.dnaView),
    0,
  );

  // The gene comes up out of the band's mark of it a little before the map
  // starts to give way.
  @override
  double asChild(double progress) => smoothstep((progress - 0.25) / 0.45);

  // On the way to the DNA the DNA's scene draws the gene's DNA from the
  // first ([DnaScene]); this one draws only what names it, gone before the
  // nucleosomes wind in their DNA, and goes after it.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.5) / 0.45);

  /// How much the ruler, the exons' numbers, the start and the 3′ end show
  /// at [frame]: they come up over the end of the step that reaches the
  /// gene, once the band's map has given way, and go first on the way to
  /// the DNA, gone before the nucleosomes start to wind in their DNA
  /// ([DnaDive.windsFrom]).
  @visibleForTesting
  double annotationsShown(ZoomFrame frame) => frame.isChild
      ? smoothstep((frame.progress - 0.55) / 0.45)
      : 1 - _leaving(frame);

  /// How far the step has gone, at [frame] on the way to the DNA, from the
  /// gene's stop to where its nucleosomes start to wind in their DNA, in
  /// the step's own depth:
  /// a long gene's empty decades go by fast, and a fade keyed to them would
  /// go as fast.
  double _leaving(ZoomFrame frame) {
    final DnaDive dive = subject.depth.dive;
    // Over a sixth of the step at the least, so a gene whose DNA packs soon
    // after its stop does not drop them in a few frames; they are faint by
    // then.
    return smoothstep(
      frame.progress / math.max(dive.spentAt(DnaDive.windsFrom(_width)), 0.15),
    );
  }

  /// The screen x of [offset] base pairs into the gene, facing as it does.
  double _x(ZoomFrame frame, double offset) {
    final double centre = frame.toScreen(Offset.zero).dx;
    final double x = frame.toScreen(Offset(unitAlong(offset), 0)).dx;
    return centre + (x - centre) * _facing;
  }

  /// Where the point [offset] base pairs into the gene from its 5′ end lies
  /// across the screen at [frame].
  @visibleForTesting
  double screenX(ZoomFrame frame, double offset) => _x(frame, offset);

  /// How far below the line the gene's names hang: the top of their plates,
  /// in pixels.
  static const double namesBelow = 26;

  /// What the gene's stop names on a canvas [width] wide ([GeneNames]).
  @visibleForTesting
  GeneNames namesAt(double width) =>
      _names[width] ??= GeneNames.of(subject, width);
  final Map<double, GeneNames> _names = <double, GeneNames>{};

  // The gene's 5′ end, where transcription starts; and
  // below the line, in a row, quiet as the nucleolus's name is, its parts
  // (the user's choice of 2026-10-16: labelled hints, as the picture alone
  // did not say what everything was): an exon, an untranslated part, an
  // intron and a nucleosome. They come up with the ruler and the numbers,
  // and go with them.
  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double mid = frame.size.height / 2;
    final Offset start = Offset(_x(frame, 0), mid - 12);
    out.item('gene:start', start, frame.opacity);
    out.callout(
      'gene',
      '5′ · transcription start',
      start,
      calloutPresence(frame),
    );
    final double shown = math.min(
      calloutPresence(frame),
      annotationsShown(frame),
    );
    if (shown <= 0) {
      return;
    }
    final GeneNames names = namesAt(frame.size.width);
    void name(String key, String text, Offset target) => out.callout(
      key,
      text,
      target,
      shown,
      quiet: true,
      row: mid + namesBelow,
    );
    double middle(GenePiece piece) =>
        (_x(frame, piece.start) + _x(frame, piece.end)) / 2;
    final GenePiece? exon = names.exon;
    if (exon != null) {
      name('gene:exon', 'exon', Offset(middle(exon), mid + GeneStrand.coding));
    }
    final GenePiece? utr = names.utr;
    if (utr != null) {
      name(
        'gene:utr',
        'UTR',
        Offset(middle(utr), mid + GeneStrand.untranslated),
      );
    }
    final double? intron = names.intron;
    if (intron != null) {
      name('gene:intron', 'intron', Offset(_x(frame, intron), mid));
    }
    final int? nucleosome = names.nucleosome;
    if (nucleosome != null) {
      // On the bead's lower edge: its DNA's turns, as large as it is drawn.
      final (int _, double perBase, double grown) = _beads(frame);
      final double scale = subject.track.geneLengthBp / subject.layout.length;
      name(
        'gene:nucleosome',
        'nucleosome',
        Offset(
          _x(frame, ChromatinBeads.placeOf(nucleosome) / scale),
          mid +
              ChromatinLayout.radius *
                  ChromatinFibre.magnified(perBase, grown) *
                  perBase,
        ),
      );
    }
  }

  /// The nucleosomes the gene's stop shows at [frame], as the least depth
  /// of them ([ChromatinBeads.depthAt]); how many pixels a base pair of the
  /// genome is; and how far they have grown to their least size, never
  /// larger than the room between them as the gene opens out.
  (int, double, double) _beads(ZoomFrame frame) {
    final double scale = subject.track.geneLengthBp / subject.layout.length;
    final int depth = ChromatinBeads.depthAt(_width, frame.size.width);
    final double perBase =
        (_x(frame, 1000 / scale) - _x(frame, 0)).abs() / 1000;
    final double room = (1 << depth) * ChromatinLayout.period * perBase;
    return (depth, perBase, math.min(1, room / ChromatinBeads.apart));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double mid = frame.size.height / 2;
    final double annotations = annotationsShown(frame);
    // On the step that reaches the gene this scene draws its DNA; from the
    // gene's stop on the DNA's scene does, drawing the same. Its beads and
    // the DNA either side of it come up with its annotations.
    if (frame.isChild) {
      _strand(canvas, frame, mid, annotations);
    }
    if (annotations > 0) {
      _numbers(canvas, frame, mid, annotations);
      _ends(canvas, frame, mid, annotations);
      _ruler(canvas, frame, mid + rulerY, annotations);
    }
  }

  /// The gene's DNA, as the DNA's scene draws it from the gene's stop on
  /// ([ChromatinFibre]): its exons' bands, and over them its line, the DNA
  /// either side of it and its nucleosomes [around] of the way up, the DNA
  /// along its exons in their colours.
  void _strand(Canvas canvas, ZoomFrame frame, double mid, double around) {
    final ZoomInks inks = frame.inks;
    final double w = frame.size.width;
    // The genome's base pairs, as the DNA counts them, to the record's.
    final double scale = subject.track.geneLengthBp / subject.layout.length;
    double x(double offset) => _x(frame, offset / scale);
    final double end = subject.track.geneLengthBp.toDouble();
    GeneStrand.bands(
      canvas,
      inks,
      subject.layout,
      x: (double offset) => _x(frame, offset),
      mid: mid,
      width: w,
    );
    // The nucleosomes its stop shows, coming up with it: which they are
    // does not change as the gene opens out, and they grow with it, never
    // larger than the room between them.
    final (int depth, double perBase, double grown) = _beads(frame);
    ChromatinFibre.paint(
      canvas,
      inks,
      x: x,
      perBase: perBase,
      grown: grown,
      mid: mid,
      width: w,
      packed: 0,
      thick: GeneStrand.line,
      twist: 0,
      marks: subject.fibreMarks,
      colourAt: (double offset) {
        final Color ink = GeneStrand.ink(
          inks,
          subject.layout.kindAt(offset / scale),
        );
        return offset < 0 || offset > end
            ? ink.withValues(alpha: ink.a * around)
            : ink;
      },
      depth: depth,
      shownOf: (int index) =>
          ChromatinBeads.depthOf(index) >= depth ? around : 0,
    );
  }

  /// The least width, in pixels, a coding exon has at the gene's stop to be
  /// numbered there.
  static const double numbered = 16;

  /// The coding exons' numbers at [frame], as they are set over their
  /// blocks ([exonNumberLeft]): each exon wide enough at the gene's stop to
  /// be numbered, on or near the canvas.
  @visibleForTesting
  List<MarkNumber> exonNumbers(ZoomFrame frame) =>
      _exonNumbers(frame, frame.size.height / 2);

  List<MarkNumber> _exonNumbers(ZoomFrame frame, double mid) {
    final double w = frame.size.width;
    final double scale = frame.view.pixelsPerUnit / w;
    final List<MarkNumber> out = <MarkNumber>[];
    int exon = 0;
    GenePieceKind? last;
    for (final GenePiece piece in subject.layout.pieces) {
      if (piece.kind != GenePieceKind.intron &&
          (last == null || last == GenePieceKind.intron)) {
        exon++;
      }
      last = piece.kind;
      if (piece.kind != GenePieceKind.cds) {
        continue;
      }
      final double a = _x(frame, piece.start);
      final double b = _x(frame, piece.end);
      final double left = math.min(a, b);
      final double right = math.max(a, b);
      if (right < -8 || left > w + 8 || (right - left) / scale < numbered) {
        continue;
      }
      final String text = '$exon';
      final Size size = _measure(frame, text);
      final double? at = exonNumberLeft(left, right, size.width, w);
      out.add(
        MarkNumber(
          (left + right) / 2,
          text,
          size,
          at == null ? null : Offset(at, mid - 22 - size.height / 2) & size,
        ),
      );
    }
    return out;
  }

  /// The coding exons' numbers over their blocks, [alpha] of the way up.
  void _numbers(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    // How many times as big as at its stop the gene is drawn: an exon's
    // number comes up as its block grows from half its size there.
    final double scale = frame.view.pixelsPerUnit / frame.size.width;
    final double grown = smoothstep(math.log(2 * scale) / math.ln2);
    if (alpha * grown <= 0) {
      return;
    }
    for (final MarkNumber number in _exonNumbers(frame, mid)) {
      final Rect? box = number.box;
      if (box != null) {
        _numberAt(canvas, frame, number.text, box.topLeft, alpha * grown);
      }
    }
  }

  /// How large [text] is set in the scene's small words.
  Size _measure(ZoomFrame frame, String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: frame.labels),
      textDirection: TextDirection.ltr,
    )..layout();
    final Size size = painter.size;
    painter.dispose();
    return size;
  }

  /// [text] in the scene's small words, its top left at [at].
  void _numberAt(
    Canvas canvas,
    ZoomFrame frame,
    String text,
    Offset at,
    double alpha,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: frame.labels.copyWith(
          color: frame.inks.label.withValues(alpha: frame.opacity * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }

  /// Where the gene's ruler runs, in pixels from the middle of the view.
  static const double rulerY = -84;

  void _number(
    Canvas canvas,
    ZoomFrame frame,
    String text,
    Offset at, [
    double alpha = 1,
  ]) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: frame.labels.copyWith(
          color: frame.inks.label.withValues(alpha: frame.opacity * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  /// 3′ at the gene's far end, over the DNA going on past it; its 5′ end
  /// has the scene's callout.
  void _ends(Canvas canvas, ZoomFrame frame, double mid, double alpha) {
    final double end = _x(frame, subject.layout.length);
    if (end > -8 && end < frame.size.width - 24) {
      _number(canvas, frame, '3′', Offset(end + 10, mid - 16), alpha);
    }
  }

  /// The ruler's ticks at [frame], left to right: where each is along the
  /// gene, in base pairs from its 5′ end, and where it is on screen.
  List<(double, double)> _ticks(ZoomFrame frame) {
    final double atLeft = _along(frame, 0);
    final double atRight = _along(frame, frame.size.width);
    final double from = math.min(atLeft, atRight);
    final double to = math.max(atLeft, atRight);
    final double step = roundStep((to - from) / 4);
    return <(double, double)>[
      for (
        double at = math.max(0, (from / step).ceil() * step);
        at <= math.min(to, subject.layout.length);
        at += step
      )
        (at, _x(frame, at)),
    ]..sort(((double, double) a, (double, double) b) => a.$2.compareTo(b.$2));
  }

  /// The ruler's numbers at [frame], left to right, as they are set over
  /// their ticks ([rulerNumberLefts]): every tick's but the 5′ end's.
  @visibleForTesting
  List<MarkNumber> rulerNumbers(ZoomFrame frame) =>
      _rulerNumbers(frame, frame.size.height / 2 + rulerY);

  List<MarkNumber> _rulerNumbers(ZoomFrame frame, double y) {
    final List<double> marks = <double>[];
    final List<String> texts = <String>[];
    final List<Size> sizes = <Size>[];
    for (final (double at, double x) in _ticks(frame)) {
      if (at > 0) {
        final String text = '+${basePairLabel(at)}';
        marks.add(x);
        texts.add(text);
        sizes.add(_measure(frame, text));
      }
    }
    final List<double?> lefts = rulerNumberLefts(marks, <double>[
      for (final Size size in sizes) size.width,
    ], frame.size.width);
    return <MarkNumber>[
      for (int i = 0; i < marks.length; i++)
        MarkNumber(
          marks[i],
          texts[i],
          sizes[i],
          lefts[i] == null
              ? null
              : Offset(lefts[i]!, y - 14 - sizes[i].height / 2) & sizes[i],
        ),
    ];
  }

  /// A ruler from the 5′ end, in base pairs along the gene, its numbers
  /// whole on the canvas ([rulerNumberLefts]).
  void _ruler(Canvas canvas, ZoomFrame frame, double y, double alpha) {
    final double w = frame.size.width;
    final Paint rule = Paint()
      ..strokeWidth = 1
      ..color = frame.inks.outline.withValues(alpha: frame.opacity * alpha);
    canvas.drawLine(Offset(0, y), Offset(w, y), rule);
    rule.color = frame.inks.label.withValues(alpha: frame.opacity * alpha);
    for (final (double _, double x) in _ticks(frame)) {
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), rule);
    }
    for (final MarkNumber number in _rulerNumbers(frame, y)) {
      final Rect? box = number.box;
      if (box != null) {
        _numberAt(canvas, frame, number.text, box.topLeft, alpha);
      }
    }
  }

  /// Base pairs along the gene from its 5′ end at screen x [x].
  double _along(ZoomFrame frame, double x) {
    final double centre = frame.toScreen(Offset.zero).dx;
    final double genomeX = centre + (x - centre) / _facing;
    final double unit = frame.view
        .fromScreen(Offset(genomeX, 0), frame.size)
        .dx;
    final double position = subject.geneMiddle + unit * _width;
    final double fraction = _reverse
        ? (subject.track.spanEnd - position) / subject.track.geneLengthBp
        : (position - subject.track.spanStart) / subject.track.geneLengthBp;
    return fraction * subject.layout.length;
  }
}

/// What the gene's stop names besides its ends, each chosen by rule from
/// the record at the stop's scale, so that none changes on the way to the
/// stop or from it: the widest coding part of an exon, the widest
/// untranslated part where it is wide enough to point at, the widest
/// intron, and a nucleosome on the line clear of the exons.
@immutable
final class GeneNames {
  const GeneNames({this.exon, this.utr, this.intron, this.nucleosome});

  factory GeneNames.of(ZoomSubject subject, double width) {
    final GeneLayout layout = subject.layout;
    final double gene = subject.depth.widthOf(ZoomStop.gene);
    // The genome's base pairs to the record's, and pixels to the genome's
    // base pair at the stop.
    final double scale = subject.track.geneLengthBp / layout.length;
    final double perBase = width / gene;
    GenePiece? widest(GenePieceKind kind) {
      GenePiece? best;
      for (final GenePiece piece in layout.pieces) {
        if (piece.kind == kind && (best == null || piece.length > best.length)) {
          best = piece;
        }
      }
      return best;
    }

    GenePiece? utr = widest(GenePieceKind.utr);
    if (utr != null && utr.length * scale * perBase < leastUtr) {
      utr = null;
    }
    // The nucleosomes the stop shows, in order along the gene, and how far
    // each reaches either side of its middle, in the genome's base pairs.
    final double end = subject.track.geneLengthBp.toDouble();
    final List<double> beads = <double>[
      for (final int index in ChromatinBeads.within(
        -gene,
        end + gene,
        ChromatinBeads.depthAt(gene, width),
      ))
        ChromatinBeads.placeOf(index),
    ];
    // The first in the gene clear of every exon, or where the exons leave
    // none clear, the one farthest from them.
    final double reach =
        ChromatinLayout.reach * ChromatinFibre.magnified(perBase);
    double clearance(double place) {
      double least = double.infinity;
      for (final GenePiece piece in layout.pieces) {
        if (piece.kind == GenePieceKind.intron) {
          continue;
        }
        final double a = piece.start * scale;
        final double b = piece.end * scale;
        least = math.min(
          least,
          place < a ? a - place : (place > b ? place - b : 0),
        );
      }
      return least;
    }

    int? nucleosome;
    double best = -1;
    for (final int index in ChromatinBeads.within(
      0,
      end,
      ChromatinBeads.depthAt(gene, width),
    )) {
      final double place = ChromatinBeads.placeOf(index);
      if (place < 0 || place > end) {
        continue;
      }
      final double room = clearance(place);
      if (room >= reach) {
        nucleosome = index;
        break;
      }
      if (room > best) {
        best = room;
        nucleosome = index;
      }
    }
    // The intron half way between the nucleosomes either side of its
    // middle, where that is still in it: on the line, clear of both.
    double? intron;
    final GenePiece? longest = widest(GenePieceKind.intron);
    if (longest != null) {
      final double middle = (longest.start + longest.end) / 2 * scale;
      double? before;
      double? after;
      for (final double place in beads) {
        if (place <= middle) {
          before = place;
        } else {
          after ??= place;
        }
      }
      double at = middle;
      if (before != null && after != null) {
        final double between = (before + after) / 2;
        if (between > longest.start * scale && between < longest.end * scale) {
          at = between;
        }
      }
      intron = at / scale;
    }
    return GeneNames(
      exon: widest(GenePieceKind.cds),
      utr: utr,
      intron: intron,
      nucleosome: nucleosome,
    );
  }

  /// The least width, in pixels, an untranslated part has at the gene's
  /// stop to be named.
  static const double leastUtr = 6;

  /// The widest coding part of an exon.
  final GenePiece? exon;

  /// The widest untranslated part, where it is [leastUtr] wide at the stop.
  final GenePiece? utr;

  /// Where an intron is named, in base pairs of the record from the gene's
  /// 5′ end.
  final double? intron;

  /// The nucleosome named, by its index ([ChromatinBeads]): the first past
  /// the gene's start the stop shows clear of the exons, or the farthest
  /// from them where none is.
  final int? nucleosome;
}
