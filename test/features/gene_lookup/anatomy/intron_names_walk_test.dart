import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_selection_canvas.dart';
import 'package:helixpeek/shared/anatomy/anatomy_selection.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../support/test_catalog.dart';

/// A base lifted out of an intron is named where it really is: by HGVS, from
/// the nearer exon and along the real intron, a shortened one included. It
/// used to be named by its drawn cell, which past a shortened intron's cut
/// is tens of thousands of bases short.
Future<AnatomyModel> _open(
  WidgetTester tester,
  ProteinTarget target,
  String intron,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final record = GeneRecordDto.fromJson(
    jsonDecode(File(target.mockAsset).readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: AnatomyScreen(target: target, record: record),
    ),
  );
  await tester.pumpAndSettle();
  final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
  final AnatomyStage gene = model.stages.first;
  final StageRun run = gene.runs.firstWhere((StageRun r) => r.label == intron);
  tester
      .widget<AnatomyCanvas>(find.byType(AnatomyCanvas))
      .onTapped(gene.positionAt(run.start), asRun: true);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('open-dna')));
  await tester.pumpAndSettle();
  return model;
}

/// Lifts region base [cell] and gives the line the header writes for it.
Future<void> _lift(WidgetTester tester, int cell, String line) async {
  tester
      .widget<AnatomySelectionCanvas>(find.byType(AnatomySelectionCanvas))
      .onBaseTapped!(cell);
  await tester.pumpAndSettle();
  expect(find.textContaining(line, findRichText: true), findsWidgets);
}

void main() {
  testWidgets('a base of a shortened intron is named where it really is', (
    WidgetTester tester,
  ) async {
    final AnatomyModel model = await _open(
      tester,
      TestCatalog.cftr,
      'intron 1',
    );
    final AnatomyStage gene = model.stages.first;
    final AnatomyStage intron = AnatomySelection.of(
      model,
      gene.positionAt(
        gene.runs.firstWhere((StageRun r) => r.label == 'intron 1').start,
      ),
    ).stage;
    expect(intron.count, 2359);
    String at(int cell) => intron.letters[cell];
    await _lift(tester, 0, 'c.53+1 · ${at(0)} · intron 1');
    await _lift(tester, 1179, 'c.54−1,180 · ${at(1179)} · intron 1');
    await _lift(tester, 2358, 'c.54−1 · ${at(2358)} · intron 1');
    expect(find.textContaining('base 2,359', findRichText: true), findsNothing);
  });

  testWidgets('a base of an intron in the 5′ UTR is named from the UTR', (
    WidgetTester tester,
  ) async {
    final AnatomyModel model = await _open(
      tester,
      TestCatalog.insulin,
      'intron 1',
    );
    final AnatomyStage gene = model.stages.first;
    final StageRun run = gene.runs.firstWhere(
      (StageRun r) => r.label == 'intron 1',
    );
    final String last = gene.letters[run.start + run.count - 1];
    await _lift(tester, run.count - 1, 'c.−17−1 · $last · intron 1');
  });
}
