import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/clinvar/variants_overview.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/anatomy/stage_bar.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import 'gene_clinvar_test.dart' show snapshot;
import 'variant_evidence_test.dart' show insulinConstraint, insulinImpact;

/// A ClinVar record's "Residue ›" on a base sheet, and its "Base ›" on a
/// residue sheet, open a landing above the walk, as the list's links do (the
/// user's ask, 2026-11-15). Back, or the landing's header, which names the
/// sheet, returns to that sheet exactly as it was: its record open, scrolled
/// where it was. Until then the link was a jump in the walk itself, which
/// took the sheet away and left nothing to go back to.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// Every walk, the reader's own and each landing above it, built or not.
Finder get _walks => find.byType(AnatomyScreen, skipOffstage: false);

/// c.268, Gly90's first base, and its one record: G90C.
const int _c268 = 6278;
const String _g90c = '21118';

/// c.287, Cys96's second base, where ClinVar has C96Y; and C96R, at c.286.
const int _c287 = 6297;
const String _c96y = '13387';
const String _c96r = '918067';

/// The walk with every track injected, under the app's own theme with the
/// walk's inside it, turned [pages] pages on: 1 is the mRNA, 2 the protein.
Future<void> _walk(
  WidgetTester tester, {
  required int pages,
  required bool motion,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('capture'),
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
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

/// Opens base [position]'s sheet on the mRNA page on screen.
Future<void> _tapBase(WidgetTester tester, int position) async {
  tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(position);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pumpAndSettle();
}

/// Opens residue [number]'s sheet on the protein page on screen.
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pumpAndSettle();
}

/// Brings a keyed widget on screen, scrolling the ClinVar list to a row it
/// has not built yet.
Future<void> _bringUp(WidgetTester tester, String key) async {
  if (_key(key).evaluate().isEmpty &&
      find.byType(VariantsOverview).evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      _key(key),
      200,
      scrollable: find.descendant(
        of: _key('variants-overview-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await _bringUp(tester, key);
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// How the open sheet stands: how far its content is scrolled, and its
/// height.
(double, double) _sheet(WidgetTester tester, String scrollKey) {
  final ScrollableState content = tester.state<ScrollableState>(
    find
        .descendant(of: _key(scrollKey), matching: find.byType(Scrollable))
        .first,
  );
  final DraggableScrollableSheet sheet = tester
      .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet));
  return (content.position.pixels, sheet.controller!.size);
}

/// The way back the header names, and what it says.
String? _returnLabel(WidgetTester tester) {
  final Finder back = _key('walk-return-sheet');
  if (back.evaluate().isEmpty) {
    return null;
  }
  return tester
      .widget<Text>(find.descendant(of: back, matching: find.byType(Text)))
      .data;
}


/// Writes the screen to `$SHOT_DIR/<name>.png`, where SHOT_DIR is set.
Future<void> _capture(WidgetTester tester, String name) async {
  final String? folder = Platform.environment['SHOT_DIR'];
  if (folder == null) {
    return;
  }
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(const ValueKey<String>('capture')),
  );
  await tester.runAsync(() async {
    final ui.Image shot = await boundary.toImage(pixelRatio: 2);
    final ByteData bytes = (await shot.toByteData(
      format: ui.ImageByteFormat.png,
    ))!;
    Directory(folder).createSync(recursive: true);
    File('$folder/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    shot.dispose();
  });
}

int _stage(WidgetTester tester) =>
    tester.widget<StageBar>(find.byType(StageBar)).index;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final bool motion in <bool>[false, true]) {
    final String mode = motion ? 'with motion' : 'with motion reduced';

    testWidgets('a base sheet\'s Residue › lands above the walk; Back and the '
        'header return to the sheet as it was ($mode)', (tester) async {
      await _walk(tester, pages: 1, motion: motion);
      await _tapBase(tester, _c268);
      expect(tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
          'c.268');
      await _tapKey(tester, 'evidence-row-$_g90c');
      await _bringUp(tester, 'evidence-residue-$_g90c');
      final (double scrolled, double height) =
          _sheet(tester, 'impact-panel-scroll');
      expect(scrolled, greaterThan(0));

      for (final bool header in <bool>[false, true]) {
        await tester.tap(_key('evidence-residue-$_g90c'));
        await tester.pumpAndSettle();
        // A page of its own over the walk, on Gly90's sheet, its way back
        // named by the sheet it came from.
        expect(_walks, findsNWidgets(2));
        expect(
          tester
              .widget<ConstraintPanel>(find.byType(ConstraintPanel))
              .residue
              .number,
          90,
        );
        expect(_stage(tester), 2);
        expect(_returnLabel(tester), 'c.268');
        expect(_key('walk-return-clinvar'), findsNothing);
        if (!motion && !header) {
          await _capture(tester, 'sheet-landing-gly90');
        }

        if (header) {
          await tester.tap(_key('walk-return-sheet'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        // The walk as it was left: the mRNA page, c.268's sheet, the record
        // still open and the sheet scrolled where it was.
        expect(_walks, findsOneWidget);
        expect(_stage(tester), 1);
        expect(find.byType(ConstraintPanel), findsNothing);
        expect(tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
            'c.268');
        expect(_key('evidence-detail-$_g90c'), findsOneWidget);
        expect(_sheet(tester, 'impact-panel-scroll'), (scrolled, height));
        expect(_key('walk-return-sheet'), findsNothing);
        if (!motion && header) {
          await _capture(tester, 'sheet-landing-back-c268');
        }
      }

      // The sheet keeps its own Back: the next one closes it, and the walk
      // stays on its page.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ImpactPanel), findsNothing);
      expect(_stage(tester), 1);
    });

    testWidgets('a residue sheet\'s Base › lands above the walk, named by '
        'the residue ($mode)', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _walk(tester, pages: 2, motion: motion);
      await _tapResidue(tester, 96);
      await _tapKey(tester, 'evidence-row-$_c96y');
      await _bringUp(tester, 'evidence-base-$_c96y');
      final (double, double) before = _sheet(tester, 'constraint-panel-scroll');

      await tester.tap(_key('evidence-base-$_c96y'));
      await tester.pumpAndSettle();
      expect(_walks, findsNWidgets(2));
      expect(_stage(tester), 1);
      final ImpactPanel sheet = tester.widget<ImpactPanel>(
        find.byType(ImpactPanel),
      );
      expect(sheet.impact.position, _c287);
      expect(sheet.address, 'c.287');
      expect(_returnLabel(tester), 'Cys96');
      expect(find.bySemanticsLabel('Back to Cys96'), findsOneWidget);

      await tester.tap(_key('walk-return-sheet'));
      await tester.pumpAndSettle();
      expect(_walks, findsOneWidget);
      expect(_stage(tester), 2);
      expect(
        tester
            .widget<ConstraintPanel>(find.byType(ConstraintPanel))
            .residue
            .number,
        96,
      );
      expect(_key('evidence-detail-$_c96y'), findsOneWidget);
      expect(_sheet(tester, 'constraint-panel-scroll'), before);
      semantics.dispose();
    });

    testWidgets('in a sheet\'s landing a link to that sheet goes back to it; '
        'any other is a jump there ($mode)', (tester) async {
      await _walk(tester, pages: 1, motion: motion);
      await _tapBase(tester, _c287);
      await _tapKey(tester, 'evidence-row-$_c96y');
      await _tapKey(tester, 'evidence-residue-$_c96y');
      expect(_returnLabel(tester), 'c.287');

      // C96R sits at c.286: a jump inside the landing, which keeps its way
      // back to c.287.
      await _tapKey(tester, 'evidence-row-$_c96r');
      await _tapKey(tester, 'evidence-base-$_c96r');
      expect(_walks, findsNWidgets(2));
      expect(
        tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
        'c.286',
      );
      expect(_returnLabel(tester), 'c.287');
      // And from there to Cys96 again, a jump too: the landing came from
      // c.287, not from this residue.
      await _tapKey(tester, 'evidence-row-$_c96r');
      await _tapKey(tester, 'evidence-residue-$_c96r');
      expect(_walks, findsNWidgets(2));
      expect(
        tester
            .widget<ConstraintPanel>(find.byType(ConstraintPanel))
            .residue
            .number,
        96,
      );

      // C96Y is at c.287 itself: its Base › goes back to the sheet the
      // landing came from, rather than drawing c.287 a second time.
      await _tapKey(tester, 'evidence-row-$_c96y');
      await _tapKey(tester, 'evidence-base-$_c96y');
      expect(_walks, findsOneWidget);
      expect(_stage(tester), 1);
      expect(
        tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
        'c.287',
      );
      expect(_key('evidence-detail-$_c96y'), findsOneWidget);
    });

    testWidgets('a sheet\'s landing opens the list over itself, whose own '
        'landings go back to it ($mode)', (tester) async {
      await _walk(tester, pages: 1, motion: motion);
      await _tapBase(tester, _c268);
      await _tapKey(tester, 'evidence-row-$_g90c');
      await _tapKey(tester, 'evidence-residue-$_g90c');
      expect(_returnLabel(tester), 'c.268');

      // All › on Gly90's sheet: the list rises over the landing, opened on
      // the residue's record. There is no list under a sheet's landing to go
      // back to.
      await _tapKey(tester, 'clinvar-open-all');
      expect(find.byType(VariantsOverview), findsOneWidget);
      expect(_walks, findsNWidgets(2));
      expect(
        tester.widget<VariantsOverview>(find.byType(VariantsOverview)).focus,
        <String>[_g90c],
      );

      // A record's link there opens a landing above the list, as from any
      // list, and that landing's All › goes back down to it.
      await _tapKey(tester, 'evidence-base-$_g90c');
      expect(_walks, findsNWidgets(3));
      expect(_key('walk-return-clinvar'), findsOneWidget);
      expect(_key('walk-return-sheet'), findsNothing);
      await _tapKey(tester, 'clinvar-open-all');
      expect(find.byType(VariantsOverview), findsOneWidget);
      expect(_walks, findsNWidgets(2));

      // Closed, the list leaves the landing as it was.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(VariantsOverview), findsNothing);
      expect(_returnLabel(tester), 'c.268');
      expect(
        tester
            .widget<ConstraintPanel>(find.byType(ConstraintPanel))
            .residue
            .number,
        90,
      );

      // The ESM-2 bar's ClinVar key does the same.
      await tester.tap(_key('conservation-toggle'));
      await tester.pumpAndSettle();
      await tester.tap(_key('clinvar-key'));
      await tester.pumpAndSettle();
      expect(find.byType(VariantsOverview), findsOneWidget);
      expect(_walks, findsNWidgets(2));
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await tester.tap(_key('walk-return-sheet'));
      await tester.pumpAndSettle();
      expect(_walks, findsOneWidget);
      expect(
        tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
        'c.268',
      );
      expect(_key('evidence-detail-$_g90c'), findsOneWidget);
    });
  }

  testWidgets('a link tapped twice opens one landing', (tester) async {
    await _walk(tester, pages: 1, motion: true);
    await _tapBase(tester, _c268);
    await _tapKey(tester, 'evidence-row-$_g90c');
    await _bringUp(tester, 'evidence-residue-$_g90c');
    await tester.tap(_key('evidence-residue-$_g90c'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_key('evidence-residue-$_g90c'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_walks, findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_walks, findsOneWidget);
    expect(find.byType(ImpactPanel), findsOneWidget);
  });

  testWidgets('Back while a landing slides in returns to the sheet', (
    tester,
  ) async {
    await _walk(tester, pages: 1, motion: true);
    await _tapBase(tester, _c268);
    await _tapKey(tester, 'evidence-row-$_g90c');
    await _bringUp(tester, 'evidence-residue-$_g90c');
    final (double, double) before = _sheet(tester, 'impact-panel-scroll');
    await tester.tap(_key('evidence-residue-$_g90c'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Nothing landed in the walk while the reader was not looking.
    expect(_walks, findsOneWidget);
    expect(_stage(tester), 1);
    expect(find.byType(ConstraintPanel), findsNothing);
    expect(
      tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address,
      'c.268',
    );
    expect(_key('evidence-detail-$_g90c'), findsOneWidget);
    expect(_sheet(tester, 'impact-panel-scroll'), before);
    // And the link opens again.
    await tester.tap(_key('evidence-residue-$_g90c'));
    await tester.pumpAndSettle();
    expect(_walks, findsNWidgets(2));
  });
}
