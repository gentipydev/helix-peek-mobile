import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/evidence_sections.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// The ClinVar plot's ground and ceiling (2026-11-18, the user's ask):
/// - the protein's pieces are named where a name fits, as before; a run of
///   numbered pieces takes one name, a short form is set over a piece too
///   narrow for it where it is clear, a piece cut out keeps its notch, and an
///   unnamed stretch of the chain keeps only its tick. Dystrophin's whole
///   protein read as 53 notches and not one name;
/// - the AVI scale stops at 40 for every gene, as the base sheet's bars and
///   the AVI and ESM-2 scatter do, rather than at the gene's highest record.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The plot's span on a 390-point phone: the page's 16-point margins, then
/// the strip's 30-point gutter and 8 at its right.
const double _left = 30;
const double _right = 390 - 32 - 8;

double _sans(String text) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: AppTypography.sansFamily,
        fontSize: 11,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

/// The ground as it was drawn until 2026-11-18: each piece named where a
/// name fits it, and every other piece a notch.
({List<(String, double)> names, List<double> notches}) _before(
  List<ConstraintRegion> regions,
  double Function(double) x,
) {
  final List<(String, double)> names = <(String, double)>[];
  final List<double> notches = <double>[];
  for (final ConstraintRegion region in regions) {
    final double from = x(region.start - 1.0);
    final double to = x(region.end.toDouble());
    final String? fits = <String>[
      region.label,
      region.label.split(' ').first,
      region.short,
    ].where((String s) => s.isNotEmpty && _sans(s) + 4 <= to - from).firstOrNull;
    if (fits != null) {
      names.add((fits, (from + to) / 2 - _sans(fits) / 2));
    } else {
      notches.add((from + to) / 2);
    }
  }
  return (names: names, notches: notches);
}

/// A gene's records with their scores, as the walk builds them.
List<VariantEvidence> _evidenceOf(ProteinTarget target) {
  final GeneRecord record = GeneRecordDto.fromJson(
    _json(target.mockAsset),
  ).toEntity();
  final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
  final GeneClinVar snapshot = GeneClinVar.fromJson(
    _json(target.clinvarAsset),
    target,
  );
  return VariantEvidence.build(
    snapshot,
    impact: GeneImpact.fromJson(_json(target.impactAsset), target),
    constraint: target.scored
        ? ProteinConstraint.fromJson(_json(target.constraintAsset), target)
        : null,
    nonCoding: nonCodingSections(model),
  );
}

VariantEvidence _scored(VariantEvidence e, double avi) => VariantEvidence(
  variant: e.variant,
  section: e.section,
  protein: e.protein,
  order: e.order,
  avi: avi,
  esm: e.esm,
  residue: e.residue,
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  group('the protein\'s ground at the whole view', () {
    final List<ProteinTarget> scored = <ProteinTarget>[
      for (final ProteinTarget target in TestCatalog.all)
        if (target.scored) target,
    ];

    ({List<(String, double)> names, List<double> notches}) groundOf(
      ProteinConstraint track,
    ) {
      final int length = track.sequence.length;
      double x(double u) => _left + u / length * (_right - _left);
      return EvidenceStrip.groundNames(
        track.regions,
        x: x,
        measure: _sans,
        left: _left,
        right: _right,
      );
    }

    testWidgets('every gene but three draws its ground as before', (
      WidgetTester tester,
    ) async {
      expect(scored.length, greaterThanOrEqualTo(50));
      final List<String> changed = <String>[];
      for (final ProteinTarget target in scored) {
        final ProteinConstraint track = ProteinConstraint.fromJson(
          _json(target.constraintAsset),
          target,
        );
        final int length = track.sequence.length;
        double x(double u) => _left + u / length * (_right - _left);
        final ({List<(String, double)> names, List<double> notches}) now =
            groundOf(track);
        final ({List<(String, double)> names, List<double> notches}) before =
            _before(track.regions, x);
        // The same names at the same places, and the same notches: the
        // order they are drawn in is not on the screen.
        List<(String, double)> byPlace(List<(String, double)> names) =>
            List<(String, double)>.of(names)..sort(
              ((String, double) a, (String, double) b) => a.$2.compareTo(b.$2),
            );
        final bool same =
            listEquals(byPlace(now.names), byPlace(before.names)) &&
            listEquals(
              List<double>.of(now.notches)..sort(),
              List<double>.of(before.notches)..sort(),
            );
        if (!same) {
          changed.add(target.slug);
        }
      }
      // Dystrophin's pieces, p53's stretch between its tetramerisation and
      // regulatory domains, and myoglobin's tail after its globin fold.
      expect(changed..sort(), <String>['dystrophin', 'myoglobin', 'p53']);
    });

    testWidgets('dystrophin is named, not notched', (WidgetTester tester) async {
      final ProteinConstraint track = ProteinConstraint.fromJson(
        _json(TestCatalog.dystrophin.constraintAsset),
        TestCatalog.dystrophin,
      );
      expect(track.regions, hasLength(53));
      final ({List<(String, double)> names, List<double> notches}) ground =
          groundOf(track);
      expect(ground.notches, isEmpty);
      expect(
        <String>{for (final (String text, double _) in ground.names) text},
        <String>{'CH1–2', 'Spectrin repeat 1–24', 'WW', 'ZZ'},
      );
      // In the order they stand along the protein, none on another, all in
      // the plot.
      final List<(String, double)> along =
          List<(String, double)>.of(ground.names)..sort(
            ((String, double) a, (String, double) b) => a.$2.compareTo(b.$2),
          );
      expect(<String>[for (final (String t, double _) in along) t], <String>[
        'CH1–2',
        'Spectrin repeat 1–24',
        'WW',
        'ZZ',
      ]);
      for (int i = 0; i + 1 < along.length; i++) {
        expect(
          along[i].$2 + _sans(along[i].$1) + 6,
          lessThanOrEqualTo(along[i + 1].$2),
          reason: '${along[i].$1} runs into ${along[i + 1].$1}',
        );
      }
      expect(along.first.$2, greaterThanOrEqualTo(_left));
      expect(
        along.last.$2 + _sans(along.last.$1),
        lessThanOrEqualTo(_right),
      );
    });

    testWidgets('a piece cut out keeps its notch; an unnamed stretch keeps '
        'only its tick', (WidgetTester tester) async {
      ProteinConstraint track(ProteinTarget target) =>
          ProteinConstraint.fromJson(_json(target.constraintAsset), target);
      // Insulin's two cleavage sites, at residues 55–56 and 88–89.
      final ProteinConstraint ins = track(TestCatalog.insulin);
      expect(groundOf(ins).notches, hasLength(2));
      expect(
        <String>{for (final (String t, double _) in groundOf(ins).names) t},
        <String>{'Signal', 'B chain', 'C-peptide', 'A chain'},
      );
      // Myoglobin keeps its initiator methionine's notch and drops its tail's.
      final ProteinConstraint mb = track(
        TestCatalog.all.firstWhere((ProteinTarget t) => t.slug == 'myoglobin'),
      );
      expect(groundOf(mb).notches, hasLength(1));
      expect(
        groundOf(mb).notches.single,
        _before(mb.regions, (double u) {
          return _left + u / mb.sequence.length * (_right - _left);
        }).notches.first,
      );
      // p53's stretch at 357–363 is left to its tick.
      final ProteinConstraint p53 = track(
        TestCatalog.all.firstWhere((ProteinTarget t) => t.slug == 'p53'),
      );
      expect(groundOf(p53).notches, isEmpty);
      // Glucagon's intervening peptide 1, between two cleavage sites, keeps
      // its notch: no short form can be set over it clear of theirs.
      final ProteinConstraint gcg = track(
        TestCatalog.all.firstWhere((ProteinTarget t) => t.slug == 'glucagon'),
      );
      expect(groundOf(gcg).notches, hasLength(6));
    });
  });

  group('the AVI ceiling', () {
    final ProteinTarget ins = TestCatalog.insulin;
    late final List<VariantEvidence> all = _evidenceOf(ins);
    late final GeneClinVar snapshot = GeneClinVar.fromJson(
      _json(ins.clinvarAsset),
      ins,
    );
    late final ProteinConstraint constraint = ProteinConstraint.fromJson(
      _json(ins.constraintAsset),
      ins,
    );

    /// Two protein records far apart: one in the B chain, one in the A chain.
    late final VariantEvidence near = all.firstWhere(
      (VariantEvidence e) =>
          e.avi != null && (e.variant.residue ?? 0) >= 30 &&
          (e.variant.residue ?? 0) <= 40,
    );
    late final VariantEvidence far = all.firstWhere(
      (VariantEvidence e) => e.avi != null && (e.variant.residue ?? 0) >= 100,
    );

    const ValueKey<String> capture = ValueKey<String>('ceiling-capture');

    Future<(Uint8List, int, int)> draw(
      WidgetTester tester,
      List<VariantEvidence> evidence,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.analysis,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 358,
                child: RepaintBoundary(
                  key: capture,
                  child: EvidenceStrip(
                    evidence: evidence,
                    proteinLength: snapshot.proteinSequence.length,
                    geneStart: snapshot.start,
                    geneEnd: snapshot.start + snapshot.sequence.length - 1,
                    exons: const <(int, int)>[],
                    constraint: constraint,
                    onSelected: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderRepaintBoundary boundary = tester.renderObject(
        find.byKey(capture),
      );
      return (await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        final ByteData bytes = (await image.toByteData())!;
        final (Uint8List, int, int) out = (
          bytes.buffer.asUint8List(),
          image.width,
          image.height,
        );
        image.dispose();
        return out;
      }))!;
    }

    /// Whether two drawings agree everywhere but the gutter and, if given, a
    /// band of columns around [skip].
    bool alike(
      (Uint8List, int, int) a,
      (Uint8List, int, int) b, {
      double? skip,
    }) {
      expect(a.$2, b.$2);
      expect(a.$3, b.$3);
      for (int y = 0; y < a.$3; y++) {
        for (int x = _left.toInt(); x < a.$2; x++) {
          if (skip != null && (x - skip).abs() <= 8) {
            continue;
          }
          final int i = (y * a.$2 + x) * 4;
          for (int c = 0; c < 4; c++) {
            if (a.$1[i + c] != b.$1[i + c]) {
              return false;
            }
          }
        }
      }
      return true;
    }

    double xOf(VariantEvidence e) =>
        _left +
        (e.variant.residue! - 0.5) /
            snapshot.proteinSequence.length *
            (_right - _left);

    testWidgets('a record\'s height does not depend on the gene\'s highest', (
      WidgetTester tester,
    ) async {
      final (Uint8List, int, int) low = await draw(tester, <VariantEvidence>[
        _scored(near, 30),
        _scored(far, 12),
      ]);
      final (Uint8List, int, int) high = await draw(tester, <VariantEvidence>[
        _scored(near, 30),
        _scored(far, 69),
      ]);
      // Until 2026-11-18 a record at 69 set a ceiling of 70, and every other
      // mark and the dashed line moved down for it.
      expect(alike(low, high, skip: xOf(far)), isTrue);
    });

    testWidgets('a record past 40 stands on the ceiling, which then reads '
        '40+', (WidgetTester tester) async {
      final (Uint8List, int, int) forty = await draw(tester, <VariantEvidence>[
        _scored(near, 40),
      ]);
      final (Uint8List, int, int) past = await draw(tester, <VariantEvidence>[
        _scored(near, 55),
      ]);
      expect(alike(forty, past), isTrue);
      // The gutter's number is the one thing that differs.
      bool gutterAlike() {
        for (int y = 0; y < forty.$3; y++) {
          for (int x = 0; x < _left.toInt(); x++) {
            final int i = (y * forty.$2 + x) * 4;
            for (int c = 0; c < 4; c++) {
              if (forty.$1[i + c] != past.$1[i + c]) {
                return false;
              }
            }
          }
        }
        return true;
      }

      expect(gutterAlike(), isFalse);
    });
  });
}
