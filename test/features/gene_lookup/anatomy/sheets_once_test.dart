import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/agreement_page.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';

import '../../../support/test_catalog.dart';
import '../clinvar/gene_clinvar_test.dart' show snapshot;
import '../clinvar/variant_evidence_test.dart'
    show insulinConstraint, insulinImpact;
import 'anatomy_fixture.dart';

/// The sheets say each thing once (2026-11-15): the base sheet's codon line
/// is plain and in AVI's words, with the AVI and ESM-2 page a row of its own;
/// the residue sheet reads its constraint once, without a rank, and keeps of
/// its note only the facts; an opened ClinVar record says its class once; and
/// the sheets' edges fade rather than cut through a line.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// c.268, Gly90's first base, where a change makes Cys; c.270, its last,
/// where all three keep Gly.
const int _c268 = 6278;
const int _c270 = 6280;

/// c.15, and its one record, Met5Ile, whose every condition is under its own
/// classification.
const int _c15 = 5238;
const String _m5i = '2956324';

Future<void> _walk(WidgetTester tester, {required int pages}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Theme(
        data: AppTheme.analysis,
        child: AnatomyScreen(
          record: insulin(),
          target: TestCatalog.insulin,
          constraint: insulinConstraint(),
          impact: insulinImpact(),
          clinvar: snapshot(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (int i = 0; i < pages; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tapBase(WidgetTester tester, int position) async {
  tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(position);
  await tester.pumpAndSettle();
}

Future<void> _tapResidue(WidgetTester tester, int number) async {
  final Finder canvas = find
      .byWidgetPredicate(
        (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
      )
      .first;
  final AnatomyPainter painter =
      tester.widget<CustomPaint>(canvas).painter! as AnatomyPainter;
  await tester.tapAt(
    tester.getRect(canvas).topLeft +
        painter.scene.fromLayout.centreOf(number - 1),
  );
  await tester.pumpAndSettle();
}

/// The open sheet's content, scrolled.
ScrollPosition _content(WidgetTester tester, String key) => tester
    .state<ScrollableState>(
      find.descendant(of: _key(key), matching: find.byType(Scrollable)).first,
    )
    .position;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('the base sheet names its codon plainly, and its two models\' '
      'page is a row of its own under Contributions', (tester) async {
    await _walk(tester, pages: 1);
    await _tapBase(tester, _c268);
    expect(
      tester.widget<Text>(_key('impact-note')).data,
      'codon 90 · GGC · Gly90',
    );
    expect(_key('impact-note-link'), findsNothing);
    expect(find.textContaining('constrained'), findsNothing);
    final Finder compare = _key('impact-compare-open');
    final Finder contributions = _key('impact-contributions-open');
    await tester.ensureVisible(compare);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: compare, matching: find.text('AVI and ESM-2')),
      findsOneWidget,
    );
    expect(tester.getSize(compare).height, greaterThanOrEqualTo(44));
    // Under Contributions, and in its style.
    expect(
      tester.getRect(compare).top,
      greaterThanOrEqualTo(tester.getRect(contributions).bottom),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: compare, matching: find.text('AVI and ESM-2')),
          )
          .style,
      tester
          .widget<Text>(
            find.descendant(
              of: contributions,
              matching: find.text('Contributions'),
            ),
          )
          .style,
    );
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(find.text('c.268 · AVI and ESM-2'), findsOneWidget);

    // A base whose changes all keep the amino acid has no such page, and no
    // row; its line is the same plain line.
    await tester.tap(
      find.descendant(
        of: find.byType(AgreementPage),
        matching: find.byType(CloseButton),
      ),
    );
    await tester.pumpAndSettle();
    await _tapBase(tester, _c270);
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
      'c.270',
    );
    expect(_key('impact-compare-open'), findsNothing);
    expect(
      tester.widget<Text>(_key('impact-note')).data,
      'codon 90 · GGC · Gly90',
    );
  });

  testWidgets('the residue sheet reads its constraint once, with no rank, and '
      'keeps of its note only its facts', (tester) async {
    final ProteinConstraint track = insulinConstraint();
    await _walk(tester, pages: 2);
    await _tapResidue(tester, 28);
    final ResidueConstraint gln28 = track.positions[27];
    expect(find.text('Gln28 · B4'), findsOneWidget);
    expect(find.text('B chain'), findsOneWidget);
    expect(
      (tester.widget<Text>(_key('constraint-level'))).textSpan!.toPlainText(),
      '${gln28.level.label} · ${gln28.conservation.toStringAsFixed(2)}',
    );
    expect(find.textContaining('rank'), findsNothing);
    expect(find.textContaining('constraint 0.'), findsNothing);
    expect(find.textContaining('The model'), findsNothing);
    expect(gln28.facts, isNull);
    expect(_key('constraint-facts'), findsNothing);

    // A cysteine's bridge, and a piece cut away, are facts the sheet keeps.
    for (final (int number, String facts) in <(int, String)>[
      (31, 'links the B chain to the A chain'),
      (95, 'closes a loop within the A chain'),
      (71, 'removed from the mature protein'),
      (10, 'removed from the mature protein'),
    ]) {
      expect(track.positions[number - 1].facts, facts, reason: '$number');
    }
    await _tapResidue(tester, 31);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).residue.number,
      31,
    );
    final Finder facts = _key('constraint-facts');
    await tester.ensureVisible(facts);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(facts).data, 'links the B chain to the A chain');
    // Its partner is the identity's, once.
    expect(find.textContaining('S–S Cys96 (A7)'), findsOneWidget);
  });

  testWidgets('an opened record says its class once, unless its conditions '
      'part', (tester) async {
    await _walk(tester, pages: 1);
    await _tapBase(tester, _c15);
    await tester.ensureVisible(_key('evidence-row-$_m5i'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-$_m5i'));
    await tester.pumpAndSettle();
    // M5I: one class for all its conditions, its own; the row says it.
    expect(_key('evidence-conditions-$_m5i'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('evidence-conditions-$_m5i'),
        matching: find.text('Uncertain significance'),
      ),
      findsNothing,
    );
    expect(find.text('Uncertain significance'), findsOneWidget);

    // C96Y: a conflict, each part under its own heading still.
    await _walk(tester, pages: 2);
    await _tapResidue(tester, 96);
    await tester.ensureVisible(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-13387'));
    await tester.pumpAndSettle();
    for (final String label in <String>[
      'Pathogenic',
      'Likely pathogenic',
      'Uncertain significance',
    ]) {
      expect(
        find.descendant(
          of: _key('evidence-conditions-13387'),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('a sheet\'s edges fade: its foot always, under its header once '
      'the content runs under it', (tester) async {
    await _walk(tester, pages: 2);
    await _tapResidue(tester, 90);
    expect(_key('inspector-fade-bottom'), findsOneWidget);
    expect(_key('inspector-fade-top'), findsNothing);
    // At the sheet's foot, full width.
    final Rect sheet = tester.getRect(_key('constraint-sheet-surface'));
    final Rect foot = tester.getRect(_key('inspector-fade-bottom'));
    expect(foot.bottom, sheet.bottom);
    expect(foot.width, sheet.width);
    // They take no touch.
    expect(
      find.ancestor(
        of: _key('inspector-fade-bottom'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );

    _content(tester, 'constraint-panel-scroll').jumpTo(40);
    await tester.pumpAndSettle();
    expect(_key('inspector-fade-top'), findsOneWidget);
    _content(tester, 'constraint-panel-scroll').jumpTo(0);
    await tester.pumpAndSettle();
    expect(_key('inspector-fade-top'), findsNothing);
  });
}
