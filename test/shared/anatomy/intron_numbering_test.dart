import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/shared/anatomy/anatomy_address.dart';
import 'package:helixpeek/shared/anatomy/anatomy_ruler.dart';
import 'package:helixpeek/shared/anatomy/anatomy_selection.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../support/test_catalog.dart';

/// An intron's bases are named along the real intron, never by the cell they
/// are drawn in: a shortened intron's cells past its cut are far from where
/// their cell count puts them. The region page's ruler numbers them from the
/// intron's first base, and the base sheet names them as HGVS does, from the
/// nearer exon. Both are held here to data the app does not compute: the AVI
/// track's map onto the chromosome, and ClinVar's own names for its records.
Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

AnatomyModel _model(ProteinTarget target) => AnatomyModel.derive(
  GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity(),
  chain: target.chain,
);

/// The gene page's intron runs, each as the region page it opens.
Iterable<AnatomyStage> _introns(AnatomyModel model) sync* {
  final AnatomyStage gene = model.stages.first;
  for (final StageRun run in gene.runs) {
    if (run.kind == RoleKind.intron) {
      yield AnatomySelection.of(model, gene.positionAt(run.start)).stage;
    }
  }
}

/// The region page of the intron named [label].
AnatomyStage _intron(AnatomyModel model, String label) =>
    _introns(model).firstWhere((AnatomyStage s) => s.label == label);

/// The chromosome coordinate of a record position, from the AVI track's runs.
int? _genomic(List<dynamic> runs, int local) {
  for (final dynamic raw in runs) {
    final Map<String, dynamic> run = raw as Map<String, dynamic>;
    final int start = run['local'] as int;
    final int length = run['length'] as int;
    if (local >= start && local < start + length) {
      return (run['genomic'] as int) + (run['step'] as int) * (local - start);
    }
  }
  return null;
}

String _c(AnatomyModel model, AnatomyStage region, int cell) =>
    AnatomyAddress.of(model).intronicOf(region.positionAt(cell))!;

void main() {
  test('a whole intron is numbered from its own first base, as it was', () {
    final AnatomyStage intron = _intron(
      _model(TestCatalog.insulin),
      'intron 2',
    );
    expect(AnatomyRuler.labelAt(intron, 0), '1');
    expect(AnatomyRuler.labelAt(intron, intron.count - 1), '${intron.count}');
    expect(AnatomyRuler.widest(intron), '${intron.count}'.length);
  });

  test('a shortened intron is numbered along the real one', () {
    final AnatomyModel cftr = _model(TestCatalog.cftr);
    final AnatomyStage first = _intron(cftr, 'intron 1');
    // Drawn in 2,359 cells: the first 1,179 from the donor, the rest the
    // last bases before the acceptor of an intron 24,105 bases long.
    expect(first.count, 2359);
    expect(AnatomyRuler.regionBase(first, 0), 1);
    expect(AnatomyRuler.regionBase(first, 1178), 1179);
    expect(AnatomyRuler.regionBase(first, 1179), 24105 - 1180 + 1);
    expect(AnatomyRuler.labelAt(first, first.count - 1), '24105');
    expect(AnatomyRuler.widest(first), 5);

    final AnatomyStage dmd = _intron(
      _model(TestCatalog.dystrophin),
      'intron 1',
    );
    expect(dmd.count, 758);
    expect(AnatomyRuler.labelAt(dmd, dmd.count - 1), '191081');
    expect(AnatomyRuler.widest(dmd), 6);
    expect(
      AnatomyRuler.gutterFor(dmd),
      greaterThan(AnatomyRuler.gutterFor(first)),
    );
  });

  test('the base sheet names an intronic base from the nearer exon', () {
    final AnatomyModel cftr = _model(TestCatalog.cftr);
    final AnatomyStage first = _intron(cftr, 'intron 1');
    expect(_c(cftr, first, 0), 'c.53+1');
    expect(_c(cftr, first, 1178), 'c.53+1,179');
    expect(_c(cftr, first, 1179), 'c.54−1,180');
    expect(_c(cftr, first, first.count - 1), 'c.54−1');

    final AnatomyModel dmd = _model(TestCatalog.dystrophin);
    final AnatomyStage dmdFirst = _intron(dmd, 'intron 1');
    expect(_c(dmd, dmdFirst, dmdFirst.count - 1), 'c.32−1');

    // Insulin's first intron is in its 5′ UTR, so it is named from the
    // untranslated bases either side of it.
    final AnatomyModel ins = _model(TestCatalog.insulin);
    final AnatomyStage insFirst = _intron(ins, 'intron 1');
    expect(_c(ins, insFirst, insFirst.count - 1), 'c.−17−1');
    expect(_c(ins, insFirst, 0), 'c.−18+1');

    // A base of the transcript keeps its own name, and no intronic one.
    expect(
      AnatomyAddress.of(cftr).intronicOf(cftr.stages[1].positionAt(0)),
      isNull,
    );
  });

  test('every shortened intron agrees with the chromosome AVI maps it to', () {
    int cuts = 0;
    for (final ProteinTarget target in TestCatalog.all) {
      final File avi = File(target.impactAsset);
      if (!avi.existsSync()) {
        continue;
      }
      final GeneRecord record = GeneRecordDto.fromJson(
        _json(target.mockAsset),
      ).toEntity();
      if (!record.isIntronCompressed) {
        continue;
      }
      final List<dynamic> runs = _json(avi.path)['runs'] as List<dynamic>;
      final AnatomyModel model = AnatomyModel.derive(
        record,
        chain: target.chain,
      );
      for (final AnatomyStage intron in _introns(model)) {
        if (intron.count == intron.runs.single.lengthBp) {
          continue;
        }
        cuts++;
        final int first = _genomic(runs, intron.positionAt(0))!;
        for (int cell = 0; cell < intron.count; cell++) {
          final int genomic = _genomic(runs, intron.positionAt(cell))!;
          expect(
            AnatomyRuler.regionBase(intron, cell),
            (genomic - first).abs() + 1,
            reason: '${target.gene} ${intron.label} cell $cell',
          );
        }
      }
    }
    // All sixteen shortened genes carry an AVI track, both strands among them:
    // 309 cut introns.
    expect(cuts, greaterThanOrEqualTo(300));
  });

  test('every intronic ClinVar record is named as ClinVar names it', () {
    final RegExp intronic = RegExp(r':(c\.[-*]?\d+[+-]\d+)[ACGT]>');
    final RegExp exonic = RegExp(r':(c\.[-*]?\d+)[ACGT]>');
    String plain(String c) => c.replaceAll(',', '').replaceAll('−', '-');
    int records = 0;
    int shortened = 0;
    final List<String> otherNumbering = <String>[];
    for (final ProteinTarget target in TestCatalog.all) {
      final File clinvar = File(target.clinvarAsset);
      if (!clinvar.existsSync()) {
        continue;
      }
      final GeneRecord record = GeneRecordDto.fromJson(
        _json(target.mockAsset),
      ).toEntity();
      final AnatomyModel model = AnatomyModel.derive(
        record,
        chain: target.chain,
      );
      final AnatomyAddress address = AnatomyAddress.of(model);
      // ClinVar names a record on one transcript, mostly the gene's own; a
      // name on another numbers another molecule, and is not this one's.
      final List<Map<String, dynamic>> variants = <Map<String, dynamic>>[
        for (final dynamic raw in _json(clinvar.path)['variants'] as List<dynamic>)
          raw as Map<String, dynamic>,
      ];
      final Map<String, int> transcripts = <String, int>{};
      for (final Map<String, dynamic> variant in variants) {
        final String on = (variant['name'] as String).split('(').first;
        transcripts[on] = (transcripts[on] ?? 0) + 1;
      }
      final String main = transcripts.entries
          .reduce((MapEntry<String, int> a, MapEntry<String, int> b) =>
              b.value > a.value ? b : a)
          .key;
      final Iterable<Map<String, dynamic>> named = variants.where(
        (Map<String, dynamic> v) => (v['name'] as String).startsWith('$main('),
      );
      // Where the record's own transcript numbers its exons otherwise than
      // ClinVar's does, its introns are numbered otherwise too, by the same
      // offset: that is the record's, not this numbering's.
      final bool agrees = named.every((Map<String, dynamic> v) {
        final Match? at = exonic.firstMatch(v['name'] as String);
        final String? c = address.cOf(v['position'] as int);
        return at == null || c == null || plain(c) == at.group(1);
      });
      if (!agrees) {
        otherNumbering.add(target.gene);
        continue;
      }
      for (final Map<String, dynamic> variant in named) {
        final Match? at = intronic.firstMatch(variant['name'] as String);
        final int position = variant['position'] as int;
        if (at == null ||
            model.transcriptRoleAt(position)?.kind != RoleKind.intron) {
          continue;
        }
        records++;
        if (record.isIntronCompressed) {
          shortened++;
        }
        expect(
          plain(address.intronicOf(position) ?? ''),
          at.group(1),
          reason: '${target.gene} ${variant['name']}',
        );
      }
    }
    // TP53's record numbers its first exon three bases off NM_000546.6.
    expect(otherNumbering, <String>['TP53']);
    // 5,240 records in 34 genes, 3,874 of them in shortened introns' genes.
    expect(records, greaterThanOrEqualTo(5000));
    expect(shortened, greaterThanOrEqualTo(3800));
  });
}
