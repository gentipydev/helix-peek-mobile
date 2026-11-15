import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Where a caption comes in its stage, in beats from the stage's start, and
/// how many characters it has to be read.
@immutable
final class PaceCaption {
  const PaceCaption(this.from, this.characters);

  final double from;
  final int characters;
}

/// How a stage's beats are spread over the clock. Every beat takes at least
/// [secondsPerBeat], twice the page's old two seconds, and every caption is
/// on screen at least as long as it takes to read it and watch its change
/// ([readingSeconds]), the motions under it slowed evenly to fill that time:
/// a stage that changes its caption often slows the most. Where one caption
/// gives way to the next, the speed eases from one to the other over
/// [blend] beats either side, so a motion that runs across the change never
/// jolts. A pure function of the stage's length and its captions.
@immutable
final class StagePace {
  /// [beats] long, its captions coming at [captions], in order; the first
  /// at the stage's start.
  factory StagePace(double beats, List<PaceCaption> captions) {
    assert(beats > 0, 'a stage takes time');
    // Each caption's stretch, to the next caption or the stage's end.
    final List<double> starts = <double>[0];
    final List<int> lengths = <int>[captions.isEmpty ? 0 : captions.first.characters];
    for (final PaceCaption caption in captions.skip(1)) {
      if (caption.from > starts.last && caption.from < beats) {
        starts.add(caption.from);
        lengths.add(caption.characters);
      }
    }
    final int count = starts.length;
    final List<double> ends = <double>[...starts.skip(1), beats];
    // Seconds a beat in each stretch: at least the page's beat, and the
    // stretch as long as its caption takes to read.
    final List<double> paces = <double>[];
    for (int i = 0; i < count; i++) {
      final double length = ends[i] - starts[i];
      final double read = length >= leastRead && lengths[i] > 0 ? readingSeconds(lengths[i]) : 0;
      paces.add(math.max(secondsPerBeat, read / length));
    }
    // Constant stretches, joined by ramps straddling each change.
    final List<_Piece> pieces = <_Piece>[];
    double beat = 0;
    double time = 0;
    void add(double to, double from, double into) {
      if (to - beat <= 0) {
        return;
      }
      final _Piece piece = _Piece(beat, to, time, from, into);
      pieces.add(piece);
      time = piece.endTime;
      beat = to;
    }

    for (int i = 0; i < count; i++) {
      final double half = i + 1 < count
          ? math.min(blend, 0.25 * math.min(ends[i] - starts[i], ends[i + 1] - starts[i + 1]))
          : 0;
      add(ends[i] - half, paces[i], paces[i]);
      if (half > 0) {
        add(ends[i] + half, paces[i], paces[i + 1]);
      }
    }
    return StagePace._(beats, List<_Piece>.unmodifiable(pieces), time);
  }

  const StagePace._(this.beats, this._pieces, this.seconds);

  /// A stage of [beats] at the page's beat, whatever it says.
  factory StagePace.even(double beats) => StagePace(beats, const <PaceCaption>[]);

  /// The page's beat: twice the two seconds it once was.
  static const double secondsPerBeat = 4;

  /// How long a caption of [characters] stays on screen at the least: two
  /// seconds to see what it names, and one for every fourteen characters,
  /// from five seconds to eight.
  static double readingSeconds(int characters) => (2 + characters / 14).clamp(5.0, 8.0);

  /// A caption on screen for less than this many beats is passing, not to be
  /// read, and keeps the page's beat.
  static const double leastRead = 0.25;

  /// How far either side of a caption's change, in beats, the speed eases
  /// from one stretch's to the next: no more than a quarter of either.
  static const double blend = 0.15;

  /// How many beats the stage has.
  final double beats;

  /// How long it plays, in seconds.
  final double seconds;

  final List<_Piece> _pieces;

  Duration get duration => Duration(microseconds: (seconds * 1e6).round());

  /// How far through its stage, from 0 to 1, at [fraction] of its time.
  double localAt(double fraction) {
    if (fraction <= 0) {
      return 0;
    }
    if (fraction >= 1) {
      return 1;
    }
    final double time = fraction * seconds;
    int low = 0;
    int high = _pieces.length - 1;
    while (low < high) {
      final int mid = (low + high + 1) >> 1;
      if (_pieces[mid].startTime <= time) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return (_pieces[low].beatAt(time) / beats).clamp(0.0, 1.0);
  }

  /// What fraction of its time has gone when the stage is [local] of the
  /// way through: [localAt] read backwards.
  double fractionAt(double local) {
    if (local <= 0) {
      return 0;
    }
    if (local >= 1) {
      return 1;
    }
    final double beat = local * beats;
    for (final _Piece piece in _pieces) {
      if (beat <= piece.to) {
        return (piece.timeAt(beat) / seconds).clamp(0.0, 1.0);
      }
    }
    return 1;
  }

  /// How many seconds a beat takes at [beat].
  double secondsPerBeatAt(double beat) {
    for (final _Piece piece in _pieces) {
      if (beat <= piece.to) {
        return piece.paceAt(beat);
      }
    }
    return _pieces.last.into;
  }

  /// How many seconds the stretch from beat [from] to beat [to] takes.
  double secondsBetween(double from, double to) => (fractionAt(to / beats) - fractionAt(from / beats)) * seconds;
}

/// A stretch of beats from [from] to [to], begun at [startTime] seconds, a
/// beat taking [out] seconds at its start and [into] at its end, in between
/// in a straight line.
@immutable
final class _Piece {
  const _Piece(this.from, this.to, this.startTime, this.out, this.into);

  final double from;
  final double to;
  final double startTime;
  final double out;
  final double into;

  double get _length => to - from;

  /// Half the pace's change a beat: the time to beat `from + u` is
  /// `out·u + _curve·u²`.
  double get _curve => (into - out) / (2 * _length);

  double get endTime => startTime + (out + into) / 2 * _length;

  double timeAt(double beat) {
    final double u = (beat - from).clamp(0.0, _length);
    return startTime + out * u + _curve * u * u;
  }

  double paceAt(double beat) => out + (into - out) * ((beat - from) / _length).clamp(0.0, 1.0);

  /// The beat reached [time] seconds in: the root of the time's quadratic,
  /// written so it never loses precision when the pace barely changes.
  double beatAt(double time) {
    final double spent = math.max(0.0, time - startTime);
    final double root = math.sqrt(math.max(0.0, out * out + 4 * _curve * spent));
    return math.min(to, from + 2 * spent / (out + root));
  }
}
