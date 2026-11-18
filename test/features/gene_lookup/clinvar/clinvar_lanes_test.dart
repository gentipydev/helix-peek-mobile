import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/gene_impact.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/evidence_sections.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';

/// Lanes (2026-11-18, the user's choice): where a page holds more records
/// than one plot shows truthfully — more than 800 with an AVI score in either
/// panel — each panel draws a lane per class, in the chips' order, on one
/// AVI scale. In one plot dystrophin's P/LP, painted last, took a quarter of
/// the ink for an eighth of the records. A page under the threshold, insulin
/// among them, draws as it always did.

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// A gene's strip inputs, as the walk builds them.
final class _Gene {
  _Gene(this.target) {
    final GeneRecord record = GeneRecordDto.fromJson(
      _json(target.mockAsset),
    ).toEntity();
    final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
    snapshot = GeneClinVar.fromJson(_json(target.clinvarAsset), target);
    final ProteinConstraint? track = target.scored
        ? ProteinConstraint.fromJson(_json(target.constraintAsset), target)
        : null;
    constraint = track?.sequence == snapshot.proteinSequence ? track : null;
    evidence = VariantEvidence.build(
      snapshot,
      impact: target.impactScored
          ? GeneImpact.fromJson(_json(target.impactAsset), target)
          : null,
      constraint: track,
      nonCoding: nonCodingSections(model),
    );
    exons = <(int, int)>[
      for (final Exon exon in record.exons) (exon.start, exon.end),
    ];
    runs = geneRuns(model);
    reversed = record.strand == -1;
  }

  final ProteinTarget target;
  late final GeneClinVar snapshot;
  late final ProteinConstraint? constraint;
  late final List<VariantEvidence> evidence;
  late final List<(int, int)> exons;
  late final List<GeneRun> runs;
  late final bool reversed;

  EvidenceStrip strip({
    List<VariantEvidence>? records,
    int lanesFrom = EvidenceStrip.laneThreshold,
    Set<ClinVarGroup> classes = const <ClinVarGroup>{},
    StripWindow? proteinWindow,
    StripPanel? only,
    void Function(String?, (int, int)?)? onSelected,
  }) => EvidenceStrip(
    evidence: records ?? evidence,
    proteinLength: snapshot.proteinSequence.length,
    geneStart: snapshot.start,
    geneEnd: snapshot.start + snapshot.sequence.length - 1,
    exons: exons,
    runs: runs,
    reversed: reversed,
    constraint: constraint,
    classes: classes,
    proteinWindow: proteinWindow,
    only: only,
    onClose: only == null ? null : () {},
    lanesFrom: lanesFrom,
    onSelected: onSelected ?? (_, _) {},
    onWindow: (_, _) {},
  );
}

Future<void> _host(WidgetTester tester, Widget strip) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 358,
            height: 844,
            child: SingleChildScrollView(child: strip),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _hostPage(WidgetTester tester, Widget strip) async {
  await tester.binding.setSurfaceSize(const Size(844, 390));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: strip),
    ),
  );
  await tester.pumpAndSettle();
}

/// What a panel says to a screen reader.
String _said(WidgetTester tester, StripPanel panel) => tester
    .widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(ValueKey<String>('evidence-strip-${panel.name}')),
            matching: find.byType(Semantics),
          )
          .first,
    )
    .properties
    .label!;

const String _laned = 'in a row for each class';

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

  test('a lane\'s heads fade as they crowd, whole while they have room', () {
    expect(EvidenceStrip.headOpacity(4), 1);
    expect(EvidenceStrip.headOpacity(1), 1);
    expect(EvidenceStrip.headOpacity(0.25), closeTo(0.5, 1e-9));
    // Dystrophin's VUS lane: 2,686 marks on a 320-point plot.
    expect(EvidenceStrip.headOpacity(320 / 2686), closeTo(0.345, 1e-3));
    expect(EvidenceStrip.headOpacity(1e-4), 0.12);
    expect(EvidenceStrip.headOpacity(0), 0.12);
    expect(EvidenceStrip.laneThreshold, 800);
  });

  testWidgets('the curated pages that draw lanes are the six past 800', (
    WidgetTester tester,
  ) async {
    final List<String> laned = <String>[];
    for (final ProteinTarget target in TestCatalog.all) {
      if (!target.clinvarAvailable || !target.impactScored) {
        continue;
      }
      final _Gene gene = _Gene(target);
      await _host(tester, gene.strip());
      final bool lanes = _said(tester, StripPanel.protein).contains(_laned);
      // Both panels or neither, so the page keeps one AVI scale.
      if (find
          .byKey(const ValueKey<String>('evidence-strip-dna'))
          .evaluate()
          .isNotEmpty) {
        expect(
          _said(tester, StripPanel.dna).contains(_laned),
          lanes,
          reason: target.slug,
        );
      }
      if (lanes) {
        laned.add(target.slug);
      }
    }
    // Thousands of records on the protein, or hemoglobin's 803 off it.
    expect(laned..sort(), <String>[
      'casr',
      'cftr',
      'dystrophin',
      'hemoglobin',
      'p53',
      'thyroglobulin',
    ]);
  });

  testWidgets('dystrophin\'s lanes are its classes, in the chips\' order', (
    WidgetTester tester,
  ) async {
    final _Gene dmd = _Gene(TestCatalog.dystrophin);
    await _host(tester, dmd.strip());
    expect(
      _said(tester, StripPanel.protein),
      contains('$_laned: P/LP, Conflicting, VUS and B/LB.'),
    );
    // Taller than one plot by about the rows that name the lanes, and no
    // taller than the room the page gives them.
    final double laned = tester
        .getSize(find.byKey(const ValueKey<String>('evidence-strip-protein')))
        .height;
    await _host(tester, dmd.strip(lanesFrom: 1 << 30));
    final double single = tester
        .getSize(find.byKey(const ValueKey<String>('evidence-strip-protein')))
        .height;
    expect(laned - single, inInclusiveRange(30, 60));
  });

  testWidgets('a class the chips leave out keeps its lane, and nothing '
      'moves', (WidgetTester tester) async {
    final _Gene ins = _Gene(TestCatalog.insulin);
    await _host(tester, ins.strip(lanesFrom: 0));
    expect(
      _said(tester, StripPanel.protein),
      contains('$_laned: P/LP, Conflicting, VUS, B/LB and Other.'),
    );
    // Off the protein insulin has no record of Other.
    expect(
      _said(tester, StripPanel.dna),
      contains('$_laned: P/LP, Conflicting, VUS and B/LB.'),
    );
    final Rect every = tester.getRect(
      find.byKey(const ValueKey<String>('evidence-strip-protein')),
    );
    await _host(
      tester,
      ins.strip(lanesFrom: 0, classes: <ClinVarGroup>{ClinVarGroup.benign}),
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('evidence-strip-protein')),
      ),
      every,
    );
    expect(
      _said(tester, StripPanel.protein),
      contains('$_laned: P/LP, Conflicting, VUS, B/LB and Other.'),
    );
  });

  testWidgets('a pile is its own lane\'s: two classes at one place answer '
      'apart', (WidgetTester tester) async {
    final _Gene ins = _Gene(TestCatalog.insulin);
    // Cys96Tyr (Conflicting) and Cys96Ser (Other), at one residue and, here,
    // one score: in one plot a pile of two.
    final List<VariantEvidence> two = <VariantEvidence>[
      for (final VariantEvidence e in ins.evidence)
        if (e.variant.id == '13387' || e.variant.id == '68730')
          _scored(e, 30),
    ];
    expect(two, hasLength(2));
    final List<(String?, (int, int)?)> picked = <(String?, (int, int)?)>[];
    void pick(String? id, (int, int)? cycle) => picked.add((id, cycle));
    const double width = 358 - 30 - 8;
    const double x = 30 + 95.5 / 110 * width;

    // One plot: its AVI area is the panel less 22 points of room over it
    // and 31 for the ground and its names under it.
    await _host(tester, ins.strip(records: two, onSelected: pick));
    Rect panel = tester.getRect(
      find.byKey(const ValueKey<String>('evidence-strip-protein')),
    );
    double plot = panel.height - 22 - 31;
    await tester.tapAt(
      panel.topLeft + Offset(x, 22 + plot - 2 - 0.75 * (plot - 2)),
    );
    expect(picked.last.$2, (1, 2));

    // Lanes: Conflicting over Other, the row naming the second between them.
    await _host(tester, ins.strip(records: two, lanesFrom: 0, onSelected: pick));
    panel = tester.getRect(
      find.byKey(const ValueKey<String>('evidence-strip-protein')),
    );
    plot = panel.height - 22 - 31;
    final double area = (plot - 17) / 2;
    double head(int lane) {
      final double top = 22 + lane * (area + 17);
      final double bottom = top + area;
      return bottom - 2 - 0.75 * (bottom - 2 - top);
    }

    await tester.tapAt(panel.topLeft + Offset(x, head(0)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(picked.last, ('13387', (1, 1)));
    await tester.tapAt(panel.topLeft + Offset(x, head(1)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(picked.last, ('68730', (1, 1)));
  });

  testWidgets('neither a zoom nor the page of its own switches the layout', (
    WidgetTester tester,
  ) async {
    final _Gene dmd = _Gene(TestCatalog.dystrophin);
    await _host(tester, dmd.strip(proteinWindow: (0, 40)));
    expect(_said(tester, StripPanel.protein), contains(_laned));
    await _hostPage(tester, dmd.strip(only: StripPanel.protein));
    expect(_said(tester, StripPanel.protein), contains(_laned));
    final _Gene ins = _Gene(TestCatalog.insulin);
    await _hostPage(tester, ins.strip(only: StripPanel.protein));
    expect(_said(tester, StripPanel.protein), isNot(contains(_laned)));
    expect(
      _said(tester, StripPanel.protein),
      endsWith('the top 1% genome-wide, and colours are ClinVar classes.'),
    );
  });
}
