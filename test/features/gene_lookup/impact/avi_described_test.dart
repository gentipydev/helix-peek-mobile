import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/shared/clinvar/sources_note.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import '../clinvar/gene_clinvar_test.dart' show snapshot;
import '../clinvar/variant_evidence_test.dart'
    show insulinConstraint, insulinImpact;

/// AVI is described one way wherever it is described (2026-11-18): About
/// these sources says what it integrates, and the base sheet's ⓘ and the AVI
/// and ESM-2 page's footer say the same. The footer once said AVI scores each
/// change "from the DNA", which hid the conservation and AlphaMissense that
/// make it overlap ESM-2.

/// What AVI integrates, in About's words.
const String _integrates =
    'splicing, expression, chromatin, conservation and coding predictions, '
    'AlphaMissense among them';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// c.268, Gly90's first base, where a change makes Cys.
const int _c268 = 6278;

String _said(Text text) =>
    text.data ?? text.textSpan!.toPlainText(includePlaceholders: false);

Future<void> _mrna(WidgetTester tester) async {
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
  final Rect screen = tester.getRect(find.byType(AnatomyScreen));
  await tester.dragFrom(
    Offset(screen.center.dx, screen.bottom - 40),
    const Offset(-160, 0),
  );
  await tester.pumpAndSettle();
  tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(_c268);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('About these sources names what AVI integrates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: const Scaffold(body: SingleChildScrollView(child: SourcesNote())),
      ),
    );
    final Iterable<String> said = tester
        .widgetList<Text>(find.byType(Text))
        .map(_said);
    expect(said.where((String s) => s.contains(_integrates)), isNotEmpty);
  });

  testWidgets('the base sheet\'s ⓘ says what About says AVI integrates', (
    WidgetTester tester,
  ) async {
    await _mrna(tester);
    await tester.tap(find.byTooltip('About these scores'));
    await tester.pumpAndSettle();
    final String explanation = _said(
      tester.widget<Text>(_key('impact-explanation')),
    );
    expect(explanation, contains(_integrates));
    // Still the scale, said once, and still nothing of ESM.
    expect(explanation, contains('Phred = −10 log10(1 − quantile)'));
    expect(explanation, isNot(contains('ESM')));
  });

  testWidgets('the AVI and ESM-2 page\'s footer says it too, not "from the '
      'DNA" alone', (WidgetTester tester) async {
    await _mrna(tester);
    final Finder compare = _key('impact-compare-open');
    await tester.ensureVisible(compare);
    await tester.pumpAndSettle();
    await tester.tap(compare);
    await tester.pumpAndSettle();
    final Finder source = _key('agreement-source');
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final List<String> lines = tester
        .widgetList<Text>(
          find.descendant(of: source, matching: find.byType(Text)),
        )
        .map(_said)
        .toList();
    expect(lines.where((String s) => s.contains(_integrates)), hasLength(1));
    expect(lines.where((String s) => s.contains('from the DNA,')), isEmpty);
    expect(
      lines.where(
        (String s) => s.contains('ESM-2 scores the amino acid it makes from '
            'the protein sequence alone'),
      ),
      hasLength(1),
    );
  });
}
