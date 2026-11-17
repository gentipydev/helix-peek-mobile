import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/shared/format.dart';

import '../../support/test_catalog.dart';

const ConstraintRegion _region = ConstraintRegion(
  label: 'Chain',
  short: '',
  start: 1,
  end: 10,
  origin: 1,
  kept: true,
);

/// A residue with the given scores, ranked as the parser ranks them: score
/// first, then the code, the wild type among them at zero.
ResidueConstraint _residue(String wildtype, Map<String, double> scores) {
  final List<SubstitutionScore> ranked =
      <SubstitutionScore>[
        for (final MapEntry<String, double> entry in scores.entries)
          SubstitutionScore(entry.key, entry.value),
      ]..sort((SubstitutionScore a, SubstitutionScore b) {
        final int byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.aminoAcid.compareTo(b.aminoAcid);
      });
  return ResidueConstraint(
    index: 0,
    wildtype: wildtype,
    conservation: 0.5,
    ranked: ranked,
    region: _region,
  );
}

/// Every amino acid at a distinct score below the wild type's zero, in
/// alphabetical order, with any overrides.
Map<String, double> _scores(
  String wildtype, [
  Map<String, double>? overrides,
]) {
  final Map<String, double> scores = <String, double>{};
  double next = -1;
  for (final String code in ProteinConstraint.aminoAcids.split('')) {
    if (code == wildtype) {
      scores[code] = 0;
    } else {
      scores[code] = next;
      next -= 1;
    }
  }
  return <String, double>{...scores, ...?overrides};
}

void main() {
  group('ResidueConstraint.placeOf', () {
    test('places a change among the nineteen, the highest first', () {
      final ResidueConstraint residue = _residue('C', _scores('C'));
      // A is the first code after the wild type is set aside, at −1.
      expect(residue.placeOf('A'), 1);
      expect(residue.placeOf('D'), 2);
      expect(residue.placeOf('Y'), 19);
    });

    test('the wild type is no change, and an unknown code has no place', () {
      final ResidueConstraint residue = _residue('C', _scores('C'));
      expect(residue.placeOf('C'), isNull);
      expect(residue.placeOf('X'), isNull);
    });

    test('changes that score the same share the better place', () {
      final ResidueConstraint residue = _residue(
        'C',
        _scores('C', <String, double>{'D': -1, 'E': -1}),
      );
      // A, D and E all at −1: each is first, and the next is fourth.
      expect(residue.placeOf('A'), 1);
      expect(residue.placeOf('D'), 1);
      expect(residue.placeOf('E'), 1);
      expect(residue.placeOf('F'), 4);
    });

    test('a change preferred to the wild type still counts from one', () {
      final ResidueConstraint residue = _residue(
        'C',
        _scores('C', <String, double>{'L': 2.5, 'S': 0.4}),
      );
      expect(residue.placeOf('L'), 1);
      expect(residue.placeOf('S'), 2);
      // The wild type's zero is never counted as a place above anything.
      expect(residue.placeOf('A'), 3);
    });

    test('every change of a stored track has a place from 1 to 19', () {
      final ProteinConstraint insulin = ProteinConstraint.fromJson(
        jsonDecode(File(TestCatalog.insulin.constraintAsset).readAsStringSync())
            as Map<String, dynamic>,
        TestCatalog.insulin,
      );
      for (final ResidueConstraint residue in insulin.positions) {
        final List<int> places = <int>[
          for (final SubstitutionScore s in residue.ranked)
            if (s.aminoAcid != residue.wildtype) residue.placeOf(s.aminoAcid)!,
        ];
        expect(places, hasLength(residue.ranked.length - 1));
        expect(places.first, 1, reason: residue.title);
        expect(
          places.every((int p) => p >= 1 && p <= residue.ranked.length - 1),
          isTrue,
          reason: residue.title,
        );
      }
    });
  });

  test('ordinal says a place as a reader does', () {
    expect(
      <String>[
        for (final int n in <int>[1, 2, 3, 4, 11, 12, 13, 19, 21, 22, 23, 101])
          ordinal(n),
      ],
      <String>[
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '19th',
        '21st',
        '22nd',
        '23rd',
        '101st',
      ],
    );
  });
}
