import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/gene_clinvar.dart';
import 'package:helixpeek/core/evidence/variant_evidence.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/evidence_strip.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/clinvar/evidence_sections.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show snapshot;
import 'variant_evidence_test.dart' show insulinConstraint, insulinEvidence;

/// The ClinVar page, less crowded (the user's ask, 2026-11-15): nothing
/// stands under the strip at rest, and a tapped mark is named on a card that
/// rises over the foot of the screen while it is held; the strip's marks say
/// AVI by height and ClinVar by colour, on a ground with no ESM band; and the
/// DNA panel opens folded to its title and count, which folds nothing out of
/// the list.

Finder _key(String value) =>
    find.byKey(ValueKey<String>(value), skipOffstage: false);

/// The overview over a stand-in page, as the walk pushes it.
Future<void> _overview(
  WidgetTester tester, {
  bool motion = false,
  List<String> focus = const <String>[],
  VariantsOverviewMemory? memory,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final GeneClinVar data = snapshot();
  final List<VariantEvidence> evidence = insulinEvidence();
  final List<GeneRun> runs = geneRuns(
    AnatomyModel.derive(insulin(), chain: TestCatalog.insulin.chain),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey<String>('open-overview'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => VariantsOverview(
                    snapshot: data,
                    evidence: evidence,
                    constraint: insulinConstraint(),
                    exons: <(int, int)>[
                      for (final e in insulin().exons) (e.start, e.end),
                    ],
                    runs: runs,
                    focus: focus,
                    memory: memory,
                    onOpen: (VariantTarget target) async => null,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-overview'));
  await tester.pumpAndSettle();
}

/// Where the strip draws a record's head on the protein's whole: a 30-point
/// gutter, 8 at the right, the AVI area from 22 points down to its ground
/// over a ceiling of 40, and a row of 11-point names under the ground.
Offset _head(WidgetTester tester, double u, double avi) {
  final Rect rect = tester.getRect(_key('evidence-strip-protein'));
  final double plot = rect.height - 22 - 14 - 11 - 6;
  final double ground = 22 + plot;
  final double width = rect.width - 38;
  return Offset(
    rect.left + 30 + u / 110 * width,
    rect.top + ground - 2 - avi / 40 * (ground - 2 - 22),
  );
}

EvidenceStrip _strip(WidgetTester tester) => tester.widget<EvidenceStrip>(
  find.byType(EvidenceStrip, skipOffstage: false),
);

ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// The first region's heading: the page under the strip.
Rect _underStrip(WidgetTester tester) =>
    tester.getRect(_key('variants-section-toggle-Signal peptide@1'));

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final bool motion in <bool>[false, true]) {
    final String mode = motion ? 'with motion' : 'with motion reduced';

    testWidgets('a tapped mark\'s card rises over the foot of the screen, '
        'and nothing stands there at rest ($mode)', (tester) async {
      await _overview(tester, motion: motion);
      expect(_key('evidence-readout'), findsNothing);
      expect(find.text('Tap a mark for its record'), findsNothing);
      final Rect under = _underStrip(tester);

      // Cys96's conflicting record, the first of the two heads there.
      final Offset head = _head(tester, 95.5, 31.5);
      await tester.tapAt(head);
      if (motion) {
        // On its way up from below the screen's edge.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(_key('evidence-readout'), findsOneWidget);
        expect(
          tester.getRect(_key('evidence-readout')).bottom,
          greaterThan(844 - 12),
        );
      }
      await tester.pumpAndSettle();
      expect(_strip(tester).selected, <String>{'13387'});
      final Rect card = tester.getRect(_key('evidence-readout'));
      // Over the foot of the screen, and over the page, which stays put.
      expect(card.bottom, 844 - 12);
      expect(card.left, 16);
      expect(card.right, 390 - 16);
      expect(_underStrip(tester), under);
      expect(find.text('1 of 2 here'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('evidence-readout'),
          matching: find.text('Show in list ›'),
        ),
        findsOneWidget,
      );

      // While it is up, the list's foot scrolls clear of it.
      _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_key('sources-note')).bottom,
        lessThanOrEqualTo(tester.getRect(_key('evidence-readout')).top),
      );
      _scroll(tester).jumpTo(0);
      await tester.pumpAndSettle();

      // The second head, then let go: the card goes with the mark.
      await tester.tapAt(head);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 here'), findsOneWidget);
      await tester.tapAt(head);
      await tester.pump();
      if (motion) {
        // Going down, and nothing to press on its way.
        expect(_key('evidence-readout'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(_key('evidence-readout-show'))
              .onPressed,
          isNull,
        );
      }
      await tester.pumpAndSettle();
      expect(_strip(tester).selected, isEmpty);
      expect(_key('evidence-readout'), findsNothing);
      expect(_underStrip(tester), under);
    });

    testWidgets('Show in list lets the mark\'s card go and opens its row '
        '($mode)', (tester) async {
      await _overview(tester, motion: motion);
      await tester.tapAt(_head(tester, 95.5, 31.5));
      await tester.pumpAndSettle();
      await tester.tap(_key('evidence-readout-show'));
      await tester.pumpAndSettle();
      expect(_key('evidence-readout'), findsNothing);
      expect(_key('evidence-detail-13387'), findsOneWidget);
      // The open row's mark stays ringed, as an opened row's always is.
      expect(_strip(tester).selected, <String>{'13387'});
    });
  }

  testWidgets('a row opened in the list rings its mark with no card', (
    tester,
  ) async {
    await _overview(tester);
    // The list builds its rows as they come near the screen.
    await tester.scrollUntilVisible(
      _key('evidence-row-13387'),
      200,
      scrollable: find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    expect(_strip(tester).selected, <String>{'13387'});
    expect(_key('evidence-readout'), findsNothing);
  });

  testWidgets('a sheet\'s records are opened in the list with no card and '
      'no line for them', (tester) async {
    // Cys96's three records, as its sheet's All › sends them.
    final List<String> cys96 = <String>[
      for (final VariantEvidence e in insulinEvidence())
        if (e.variant.residue == 96) e.variant.id,
    ];
    expect(cys96, hasLength(3));
    await _overview(tester, focus: cys96);
    expect(_strip(tester).selected, cys96.toSet());
    expect(_key('evidence-readout'), findsNothing);
    expect(find.textContaining('records selected'), findsNothing);
  });

  testWidgets('the card a mark was left with comes back with the list', (
    tester,
  ) async {
    final VariantsOverviewMemory memory = VariantsOverviewMemory();
    await _overview(tester, memory: memory);
    await tester.tapAt(_head(tester, 95.5, 31.5));
    await tester.pumpAndSettle();
    expect(memory.picked, '13387');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(_key('open-overview'));
    await tester.pumpAndSettle();
    expect(_key('evidence-readout'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('evidence-readout'),
        matching: find.text('Cys96Tyr'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the protein\'s ground is one colour: no ESM band, no ramp, '
      'no key line', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _overview(tester);
    expect(_key('variants-key'), findsNothing);
    expect(_key('variants-ramp'), findsNothing);
    expect(find.textContaining('ESM low'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^\d+ ClinVar records on the 110 residues of the protein\. '
            r'Heights are each record’s AVI score, with a dashed line at 20, '
            r'the top 1% genome-wide, and colours are ClinVar classes\.$'),
      ),
      findsOneWidget,
    );

    // The precursor's bar, along its middle: one colour from end to end
    // where the band had each residue's constraint on the ramp.
    final Finder panel = _key('evidence-strip-protein');
    final Rect rect = tester.getRect(panel);
    final RenderRepaintBoundary boundary = tester.renderObject(
      find.descendant(of: panel, matching: find.byType(RepaintBoundary)).first,
    );
    final ByteData pixels = (await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage();
      final ByteData? bytes = await image.toByteData();
      image.dispose();
      return bytes;
    }))!;
    final int width = rect.width.round();
    final double plot = rect.height - 22 - 14 - 11 - 6;
    final int y = (22 + plot + 5).round();
    final Set<int> colours = <int>{
      for (int x = 30 + 3; x < width - 8 - 3; x++)
        pixels.getUint32((y * width + x) * 4),
    };
    expect(colours, hasLength(1));
    semantics.dispose();
  });

  testWidgets('the DNA panel opens folded to its title and count, and opens '
      'from its title; the list keeps its records either way', (
    tester,
  ) async {
    final VariantsOverviewMemory memory = VariantsOverviewMemory();
    await _overview(tester, memory: memory);
    expect(_key('evidence-strip-dna'), findsNothing);
    expect(find.text('DNA · 5′ UTR · introns · 3′ UTR'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('evidence-count-dna')).data,
      ' · 52 records',
    );
    // Nothing to zoom while folded; the page of its own is still a key away.
    expect(_key('evidence-zoom-in-dna'), findsNothing);
    expect(_key('evidence-expand-dna'), findsOneWidget);
    expect(tester.getSize(_key('evidence-fold-dna')).height, 44);
    // Folded is not a filter.
    for (final String section in <String>[
      'Intron 2 · 32 records',
      '3′ UTR · 8 records',
    ]) {
      expect(find.text(section, skipOffstage: false), findsOneWidget);
    }

    await tester.tap(_key('evidence-fold-dna'));
    await tester.pumpAndSettle();
    expect(_key('evidence-strip-dna'), findsOneWidget);
    expect(_key('evidence-count-dna'), findsNothing);
    expect(_key('evidence-zoom-in-dna'), findsOneWidget);
    expect(memory.dnaOpen, isTrue);

    // Kept for the gene: the list opens again as it was left.
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(_key('open-overview'));
    await tester.pumpAndSettle();
    expect(_key('evidence-strip-dna'), findsOneWidget);
    await tester.tap(_key('evidence-fold-dna'));
    await tester.pumpAndSettle();
    expect(_key('evidence-strip-dna'), findsNothing);
    expect(memory.dnaOpen, isFalse);

    // The classes chosen count as the list does.
    await tester.tap(_key('variants-chip-pathogenic'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(_key('evidence-count-dna')).data,
      matches(RegExp(r'^ · \d+ of 52 records$')),
    );
  });

  testWidgets('a record off the protein, sent for, opens the DNA panel', (
    tester,
  ) async {
    await _overview(tester, focus: const <String>['211186']);
    expect(_key('evidence-strip-dna'), findsOneWidget);
    expect(_strip(tester).selected, <String>{'211186'});
  });
}
