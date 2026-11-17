import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/constraint/constraint_panel.dart';
import 'package:helixpeek/features/gene_lookup/presentation/inspector/impact_panel.dart';
import 'package:helixpeek/shared/anatomy/anatomy_painter.dart';
import 'package:helixpeek/shared/format.dart';
import 'package:helixpeek/shared/inspector/score_bar.dart';

import '../../../support/test_catalog.dart';
import '../anatomy/anatomy_fixture.dart';
import '../clinvar/gene_clinvar_test.dart' show snapshot;
import '../clinvar/variant_evidence_test.dart'
    show insulinConstraint, insulinImpact;

/// Guess first (the user's ask, 2026-11-17): the protein page's strip offers
/// "Guess", and while it is on a residue asks which change ESM-2 ranks first
/// before its sheet shows the ranking. Off, which is how every walk opens,
/// the sheet is the one it always was.

final ProteinConstraint _data = ProteinConstraint.fromJson(
  jsonDecode(File(TestCatalog.insulin.constraintAsset).readAsStringSync())
      as Map<String, dynamic>,
  TestCatalog.insulin,
);

/// Insulin's Cys31 (B7), index 30: every change scores −10.25 or lower, Arg
/// highest and His eighth, below the six the ranking leads with.
const int _cys31 = 30;

/// Gly32 (B8), the residue after it.
const int _gly32 = 31;

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder get _pill => _key('guess');
Finder get _question => _key('guess-question');
Finder get _verdict => _key('guess-verdict');
Finder _tile(String code) => _key('guess-tile-$code');
Finder get _tiles => find.byWidgetPredicate(
  (Widget w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('guess-tile-'),
);

const String _restingHint = 'Tap a residue for its ESM-2 scores';
const String _guessingHint = 'Tap a residue to guess';

Finder get _paintBox => find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is AnatomyPainter,
);
AnatomyPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintBox).painter! as AnatomyPainter;

ScrollPosition _contentPosition(WidgetTester tester) => tester
    .widget<CustomScrollView>(_key('constraint-panel-scroll'))
    .controller!
    .position;

double _sheetSize(WidgetTester tester) =>
    tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).controller.size;

/// Insulin's walk with its ESM-2 scores, turned [pages] pages on: 2 is the
/// protein page.
Future<void> _open(
  WidgetTester tester, {
  bool reduced = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  int pages = 2,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('capture'),
      child: MaterialApp(
        theme: AppTheme.analysis,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AnatomyScreen(
            target: TestCatalog.insulin,
            record: insulin(),
            constraint: _data,
          ),
        ),
      ),
    ),
  );
  await _turn(tester, pages);
}

Future<void> _turn(WidgetTester tester, int pages) async {
  for (int i = 0; i < pages; i++) {
    final Rect screen = tester.getRect(find.byType(AnatomyScreen));
    await tester.dragFrom(
      Offset(screen.center.dx, screen.bottom - 40),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
  }
}

/// Taps residue [index] and lets the mask's beat and the sheet's rise run.
Future<void> _open1(WidgetTester tester, int index) async {
  await tester.tapAt(
    tester.getRect(_paintBox).topLeft +
        _painter(tester).scene.fromLayout.centreOf(index),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester) async {
  await tester.tap(_pill);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String code) async {
  await tester.ensureVisible(_tile(code));
  await tester.pumpAndSettle();
  await tester.tap(_tile(code));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(_key('constraint-sheet-close'));
  await tester.pumpAndSettle();
}

SubstitutionBar _bar(WidgetTester tester, String code) =>
    tester.widget<SubstitutionBar>(
      find.byWidgetPredicate(
        (Widget w) => w is SubstitutionBar && w.score.aminoAcid == code,
      ),
    );

/// How strongly row [code]'s track is drawn.
double _track(WidgetTester tester, String code) => tester
    .widget<ScoreBar>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget w) => w is SubstitutionBar && w.score.aminoAcid == code,
        ),
        matching: find.byType(ScoreBar),
      ),
    )
    .trackOpacity;

Color _accent(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ConstraintPanel))).colorScheme.primary;

bool _checked(WidgetTester tester) => find
    .descendant(of: _pill, matching: find.byIcon(Icons.check_rounded))
    .evaluate()
    .isNotEmpty;

/// The labels of the custom actions the strip offers a screen reader.
List<String?> _stripActions(WidgetTester tester, String hint) {
  final SemanticsNode strip = tester.getSemantics(
    find.bySemanticsLabel(RegExp(RegExp.escape(hint))),
  );
  return <String?>[
    for (final int id
        in strip.getSemanticsData().customSemanticsActionIds ?? const <int>[])
      CustomSemanticsAction.getAction(id)?.label,
  ];
}

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

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await loadAppFonts();
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test('a score bar\'s track is drawn as it always was unless asked', () {
    const ScoreBar bar = ScoreBar(
      label: 'A',
      fraction: 0,
      value: '0.0',
      native: false,
      color: Colors.black,
      semanticsLabel: 'A',
    );
    expect(bar.trackOpacity, 0.1);
  });

  testWidgets('off, as every walk opens, the sheet is the one it always was', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    expect(_pill, findsOneWidget);
    expect(_checked(tester), isFalse);
    expect(find.text('Guess'), findsOneWidget);
    expect(find.text(_restingHint), findsOneWidget);

    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_cys31),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ConstraintPanel), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(SubstitutionBar), findsNWidgets(6));
    expect(_question, findsNothing);
    expect(_verdict, findsNothing);
    expect(_tiles, findsNothing);
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).onGuess,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip offers Guess on the scored protein page at rest '
      'alone', (WidgetTester tester) async {
    await _open(tester, pages: 0);
    // The gene page offers its own: its regions' DNA, and the zoom.
    expect(_pill, findsNothing);
    await _turn(tester, 1);
    expect(_pill, findsNothing, reason: 'the mRNA page');
    await _turn(tester, 1);
    expect(_pill, findsOneWidget, reason: 'the protein page');

    // Not while a residue is masked: the sheet is the page's subject then.
    await _open1(tester, _cys31);
    expect(_pill, findsNothing);
    await _close(tester);
    expect(_pill, findsOneWidget);

    // Nor on the pages after it, which have no residue sheet.
    await _turn(tester, 1);
    expect(_pill, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guess turns asking on and off; a tap above the pill is a tap '
      'on it', (WidgetTester tester) async {
    await _open(tester);
    await _toggle(tester);
    expect(_checked(tester), isTrue);
    expect(find.text('Guess'), findsOneWidget, reason: 'the label stays');
    expect(find.text(_guessingHint), findsOneWidget);
    expect(find.text(_restingHint), findsNothing);
    await _capture(tester, 'guess-on');

    // Over the pill, where the page's sentence runs: the strip's reach.
    await tester.tapAt(
      tester.getRect(_pill).topCenter - const Offset(0, 12),
    );
    await tester.pumpAndSettle();
    expect(_checked(tester), isFalse);
    expect(find.text(_restingHint), findsOneWidget);
    await _capture(tester, 'guess-off');
  });

  testWidgets('on, the question stands where the ranking would, after the '
      'same beat', (WidgetTester tester) async {
    await _open(tester);
    await _toggle(tester);
    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_cys31),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ConstraintPanel), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Cys31 · B7'), findsOneWidget);
    expect(find.text('Which change does ESM-2 rank first?'), findsOneWidget);
    expect(_tiles, findsNWidgets(20));
    // Nothing the sheet would say of the residue yet: not its level, not its
    // ranking, not the changes ClinVar records here.
    expect(find.byType(SubstitutionBar), findsNothing);
    expect(_key('constraint-level'), findsNothing);
    expect(_key('constraint-expand'), findsNothing);
    expect(_key('clinvar-block'), findsNothing);
    expect(_key('guess-skip'), findsOneWidget);

    // The wild type completes the twenty and cannot be picked.
    await tester.tap(_tile('C'));
    await tester.pumpAndSettle();
    expect(_question, findsOneWidget);
    expect(find.byType(SubstitutionBar), findsNothing);
    await _capture(tester, 'guess-question');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pick places itself among the nineteen, its row kept and '
      'marked', (WidgetTester tester) async {
    await _open(tester);
    await _toggle(tester);
    await _open1(tester, _cys31);
    await _pick(tester, 'H');

    expect(_question, findsNothing);
    expect(find.text('Your pick: His · 8th of 19'), findsOneWidget);
    expect(_data.positions[_cys31].placeOf('H'), 8);
    // The six it always leads with, and the pick below them.
    expect(find.byType(SubstitutionBar), findsNWidgets(7));
    expect(_key('substitution-score-H'), findsOneWidget);
    expect(_bar(tester, 'H').picked, isTrue);
    expect(_bar(tester, 'H').color, _accent(tester));
    // Every change here is below −10, so His's bar is empty: its track,
    // stronger than the others', is the mark.
    expect(_track(tester, 'H'), 0.3);
    expect(_track(tester, 'R'), 0.1);
    for (final String code in <String>['C', 'R', 'G', 'W', 'Y', 'S']) {
      expect(_bar(tester, code).picked, isFalse, reason: code);
      expect(_bar(tester, code).color, isNot(_accent(tester)), reason: code);
    }
    // The rest of the sheet is the one it always was.
    expect(_key('constraint-level'), findsOneWidget);
    expect(_key('constraint-expand'), findsOneWidget);
    expect(_contentPosition(tester).pixels, 0);
    await _capture(tester, 'guess-reveal');

    // Every verdict reads off the residue's own ranking.
    final ResidueConstraint gly32 = _data.positions[_gly32];
    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_gly32),
    );
    await tester.pumpAndSettle();
    await _pick(tester, 'A');
    expect(
      find.text(
        'Your pick: Ala · ${ordinal(gly32.placeOf('A')!)} of '
        '${gly32.ranked.length - 1}',
      ),
      findsOneWidget,
    );
    expect(find.text('Your pick: Ala · 1st of 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another residue asks again in the same sheet; an answered one '
      'shows its pick without asking', (WidgetTester tester) async {
    await _open(tester);
    await _toggle(tester);
    await _open1(tester, _cys31);
    final State panel = tester.state(find.byType(ConstraintPanel));
    final double height = _sheetSize(tester);
    await _pick(tester, 'R');
    expect(find.text('Your pick: Arg · 1st of 19'), findsOneWidget);

    // Compared in place: the same sheet, at the same height, asking.
    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_gly32),
    );
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ConstraintPanel)), same(panel));
    expect(_sheetSize(tester), closeTo(height, 0.001));
    expect(find.text('Gly32 · B8'), findsOneWidget);
    expect(_question, findsOneWidget);
    expect(_verdict, findsNothing);

    // Back to Cys31, answered: its ranking, the pick marked, no question.
    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_cys31),
    );
    await tester.pumpAndSettle();
    expect(_question, findsNothing);
    expect(find.text('Your pick: Arg · 1st of 19'), findsOneWidget);

    // And after the sheet has gone and come back.
    await _close(tester);
    await _open1(tester, _cys31);
    expect(_question, findsNothing);
    expect(_bar(tester, 'R').picked, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Show scores answers without a pick', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await _toggle(tester);
    await _open1(tester, _cys31);
    await tester.tap(_key('guess-skip'));
    await tester.pumpAndSettle();
    expect(_question, findsNothing);
    expect(_verdict, findsNothing);
    expect(find.byType(SubstitutionBar), findsNWidgets(6));
    expect(
      tester
          .widgetList<SubstitutionBar>(find.byType(SubstitutionBar))
          .where((SubstitutionBar bar) => bar.picked),
      isEmpty,
    );
    await _close(tester);
    await _open1(tester, _cys31);
    expect(_question, findsNothing);
    expect(find.byType(SubstitutionBar), findsNWidgets(6));
  });

  testWidgets('turned off, it asks no more; a pick stays marked', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await _toggle(tester);
    await _open1(tester, _cys31);
    await _pick(tester, 'H');
    await _close(tester);
    await _toggle(tester);
    expect(_checked(tester), isFalse);

    await _open1(tester, _gly32);
    expect(_question, findsNothing);
    expect(_verdict, findsNothing);
    expect(find.byType(SubstitutionBar), findsNWidgets(6));
    await _close(tester);

    await _open1(tester, _cys31);
    expect(find.text('Your pick: His · 8th of 19'), findsOneWidget);
  });

  testWidgets('with motion reduced the question is there at once', (
    WidgetTester tester,
  ) async {
    await _open(tester, reduced: true);
    await _toggle(tester);
    await tester.tapAt(
      tester.getRect(_paintBox).topLeft +
          _painter(tester).scene.fromLayout.centreOf(_cys31),
    );
    await tester.pump();
    expect(_question, findsOneWidget);
    await tester.tap(_tile('R'));
    await tester.pump();
    expect(find.text('Your pick: Arg · 1st of 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen reader hears the offer, the tiles and the verdict', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(tester);
    expect(_stripActions(tester, _restingHint), <String>[
      'Guess ESM-2’s top change before its scores',
    ]);
    await _toggle(tester);
    expect(_stripActions(tester, _guessingHint), <String>['Stop guessing']);

    await _open1(tester, _cys31);
    expect(
      tester.getSemantics(_tile('H')),
      isSemantics(label: 'histidine', isButton: true, isEnabled: true),
    );
    expect(
      tester.getSemantics(_tile('C')),
      isSemantics(
        label: 'cysteine, wild type',
        isButton: true,
        isEnabled: false,
      ),
    );
    await _pick(tester, 'H');
    expect(tester.getSemantics(_verdict), isSemantics(isLiveRegion: true));
    expect(
      find.bySemanticsLabel(RegExp(r'^H, score .*, your pick$')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    // Not `addTearDown`: the framework checks for leaked handles before tear
    // downs run.
    semantics.dispose();
  });

  testWidgets('a landing offers no Guess', (WidgetTester tester) async {
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
    await _turn(tester, 1);
    // c.268, Gly90's first base, and its record G90C, whose Residue › lands
    // on Gly90's residue sheet in a walk of its own.
    tester.widget<AnatomyCanvas>(find.byType(AnatomyCanvas)).onTapped(6278);
    await tester.pumpAndSettle();
    expect(tester.widget<ImpactPanel>(find.byType(ImpactPanel)).address, 'c.268');
    await tester.ensureVisible(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-row-21118'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('evidence-residue-21118'));
    await tester.pumpAndSettle();
    await tester.tap(_key('evidence-residue-21118'));
    await tester.pumpAndSettle();
    expect(
      find.byType(AnatomyScreen, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(
      tester.widget<ConstraintPanel>(find.byType(ConstraintPanel)).onGuess,
      isNull,
    );
    await _close(tester);
    // The landing's protein page at rest, with nothing masked: no Guess.
    expect(find.text(_restingHint), findsOneWidget);
    expect(_pill, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pill ends the hint\'s line: the sentence keeps its width, '
      'and neither hint is shrunk beside it', (WidgetTester tester) async {
    double drawn(String text) => tester.getRect(find.text(text)).width;
    double laid(String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).size.width;
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(390, 844), 1),
      (const Size(320, 640), 1),
      (const Size(320, 640), 1.2),
    ]) {
      final String at = '$size at $scale';
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, size: size, textScale: scale);
      final Rect sentence = tester.getRect(
        find.text('signal peptide 1–24 · proinsulin 25–110'),
      );
      final Rect hint = tester.getRect(find.text(_restingHint));
      expect(tester.getRect(_pill).top, greaterThan(sentence.bottom),
          reason: at);
      expect(tester.getRect(_pill).center.dy, closeTo(hint.center.dy, 1),
          reason: at);
      expect(drawn(_restingHint), closeTo(laid(_restingHint), 0.5),
          reason: at);
      await _toggle(tester);
      expect(drawn(_guessingHint), closeTo(laid(_guessingHint), 0.5),
          reason: at);
      expect(tester.takeException(), isNull, reason: at);
    }
  });

  testWidgets('a small phone with type turned up: nothing overflows and the '
      'hint is whole', (WidgetTester tester) async {
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(320, 640), 1.2),
      (const Size(320, 640), 1.5),
      (const Size(375, 667), 1.3),
    ]) {
      final String at = '$size at $scale';
      // A fresh walk each time: pumped over the last, it would keep its state,
      // Guess on.
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, size: size, textScale: scale);
      await _toggle(tester);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_guessingHint))
            .didExceedMaxLines,
        isFalse,
        reason: at,
      );
      await _open1(tester, _cys31);
      expect(_tiles, findsNWidgets(20), reason: at);
      if (size.width == 320 && scale == 1.2) {
        await _capture(tester, 'guess-question-320');
      }
      // The pick from as far down the sheet as the tiles go, then the verdict
      // at the content's top.
      await _pick(tester, 'C' == _data.positions[_cys31].wildtype ? 'P' : 'C');
      expect(_verdict, findsOneWidget, reason: at);
      expect(_contentPosition(tester).pixels, 0, reason: at);
      if (size.width == 320 && scale == 1.2) {
        await _capture(tester, 'guess-reveal-320');
      }
      expect(tester.takeException(), isNull, reason: at);
    }
  });
}
