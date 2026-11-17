import 'package:flutter/material.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/clinvar/clinvar_colors.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/inspector_sheet.dart';
import '../../../../shared/inspector/level_pips.dart';
import '../../../../shared/inspector/score_bar.dart';
import 'constraint_toolbar.dart';

/// A nonmodal sheet: the exposed grid remains interactive at every height.
///
/// The sheet itself — its resting heights, the handoff between resizing and
/// scrolling, the handle, pull-down to dismiss — is [InspectorSheet]. What is
/// here is only what a residue has to say.
class ConstraintPanel extends StatefulWidget {
  const ConstraintPanel({
    required this.residue,
    required this.length,
    required this.controller,
    required this.slide,
    required this.pinIdentity,
    required this.onDismiss,
    this.observedEvidence,
    this.reported = const <String, ClinVarGroup>{},
    this.onGuess,
    this.pick,
    super.key,
  });

  static const double minimumSize = InspectorSheet.minimumSize;
  static const double initialSize = InspectorSheet.initialSize;
  static const double maximumSize = InspectorSheet.maximumSize;

  final ResidueConstraint residue;

  /// Residues in the precursor [residue] is numbered against.
  final int length;
  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final bool pinIdentity;
  final VoidCallback onDismiss;

  /// The ClinVar records at this residue, or null for a gene without them.
  final Widget? observedEvidence;

  /// Amino acids ClinVar has a record for here, each with its most severe
  /// group. Those rows are always shown and carry the group's mark, so the
  /// ranking and the observed changes are read off the same bars.
  final Map<String, ClinVarGroup> reported;

  /// Asks the reader first. Where it is given, the sheet puts a question in
  /// the ranking's place — which change ESM-2 ranks first — and calls this
  /// with the amino acid picked, or with null for "Show scores"; the caller
  /// then hands the sheet its [pick] and takes this away. Null, the sheet
  /// shows the ranking at once, as it always has.
  final ValueChanged<String?>? onGuess;

  /// The reader's guess at this residue, which the ranking marks and the line
  /// over it places, or null for none.
  final String? pick;

  @override
  State<ConstraintPanel> createState() => _ConstraintPanelState();
}

class _ConstraintPanelState extends State<ConstraintPanel> {
  final InspectorSheetController _inspector = InspectorSheetController();
  bool _expanded = false;
  bool _explanation = false;

  void _toggleExplanation() {
    setState(() => _explanation = !_explanation);
    if (_explanation) {
      // Opening the note while scrolled down brings it into view, and grows the
      // sheet first if there is not room to read it.
      _inspector.reveal(grow: true);
    }
  }

  /// The guess, or the skip, then the ranking from its top: a tile tapped low
  /// in a short sheet would otherwise leave the line that places it scrolled
  /// out of view.
  void _answer(String? aminoAcid) {
    widget.onGuess?.call(aminoAcid);
    _inspector.reveal();
  }

  @override
  Widget build(BuildContext context) {
    final Duration crossfade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return InspectorSheet(
      sheet: widget.controller,
      controller: _inspector,
      slide: widget.slide,
      onDismiss: widget.onDismiss,
      pinIdentity: widget.pinIdentity,
      subject: widget.residue.index,
      resizeLabel: 'Resize residue details',
      surfaceKey: const ValueKey<String>('constraint-sheet-surface'),
      scrollKey: const ValueKey<String>('constraint-panel-scroll'),
      handleKey: const ValueKey<String>('constraint-sheet-handle'),
      closeKey: const ValueKey<String>('constraint-sheet-close'),
      identity: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: AnimatedSwitcher(
          duration: crossfade,
          child: _ResidueIdentity(
            key: ValueKey<int>(widget.residue.index),
            residue: widget.residue,
            explanation: _explanation,
            onExplain: _toggleExplanation,
          ),
        ),
      ),
      details: AnimatedSwitcher(
        duration: crossfade,
        child: widget.onGuess == null
            ? _Details(
                key: ValueKey<int>(widget.residue.index),
                residue: widget.residue,
                length: widget.length,
                expanded: _expanded,
                explanation: _explanation,
                onExpand: () => setState(() => _expanded = !_expanded),
                observedEvidence: widget.observedEvidence,
                reported: widget.reported,
                pick: widget.pick,
              )
            : _Guess(
                key: ValueKey<String>('guess-${widget.residue.index}'),
                residue: widget.residue,
                length: widget.length,
                explanation: _explanation,
                onAnswer: _answer,
              ),
      ),
    );
  }
}

/// The residue's name and its piece: `Gln28 · B4`, `B chain`, and a
/// cysteine's partner. Its constraint is the level line's alone, under it.
class _ResidueIdentity extends StatelessWidget {
  const _ResidueIdentity({
    required this.residue,
    required this.explanation,
    required this.onExplain,
    super.key,
  });
  final ResidueConstraint residue;
  final bool explanation;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final String? partner = residue.bondPartner;
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.anatomyColors.forResidue(residue.wildtype),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            residue.wildtype,
            style: TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: 26,
              color: theme.colorScheme.surface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(residue.title, style: theme.textTheme.titleSmall),
              Text(
                '${residue.domain}${partner == null ? '' : ' · S–S $partner'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'About these scores',
          isSelected: explanation,
          onPressed: onExplain,
          icon: const Icon(Icons.info_outline, size: 20),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.residue,
    required this.length,
    required this.expanded,
    required this.explanation,
    required this.onExpand,
    required this.reported,
    this.observedEvidence,
    this.pick,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool expanded;
  final bool explanation;
  final VoidCallback onExpand;
  final Map<String, ClinVarGroup> reported;
  final Widget? observedEvidence;

  /// The reader's guess here, or null.
  final String? pick;

  /// How many of the ranking lead the collapsed list.
  static const int _lead = 6;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color bar = theme.colorScheme.onSurfaceVariant;
    final List<SubstitutionScore> ranked = residue.ranked;
    final String? pick = this.pick;
    final int? place = pick == null ? null : residue.placeOf(pick);
    // The top six, and every change ClinVar has a record for wherever it ranks:
    // an observed change hidden under "14 more" was the one row a reader came
    // to this residue to see. The reader's own guess is kept for the same
    // reason.
    final List<int> visible = <int>[
      for (int i = 0; i < ranked.length; i++)
        if (expanded ||
            i < _lead ||
            reported.containsKey(ranked[i].aminoAcid) ||
            ranked[i].aminoAcid == pick)
          i,
    ];
    final List<int> hidden = <int>[
      for (int i = 0; i < ranked.length; i++)
        if (!visible.contains(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        // Where the guess stands among the changes, ahead of everything it is
        // checked against: the place is the ranking's own, said in words
        // because a guess below the top six sits after a gap that hides it.
        if (pick != null && place != null) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              'Your pick: ${AminoAcids.abbreviationOf(pick)} · '
              '${ordinal(place)} of ${ranked.length - 1}',
              key: const ValueKey<String>('guess-verdict'),
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 10),
        ],
        // The one reading of the residue's constraint: its band and its
        // number. Its rank in the protein, a second statement of the same
        // number, left with the line that carried it (2026-11-15), as the
        // base sheet's and the AVI and ESM-2 rows' ranks did.
        LevelPips(
          filled: switch (residue.level) {
            ConstraintLevel.high => 3,
            ConstraintLevel.middle => 2,
            ConstraintLevel.low => 1,
          },
          label: residue.level.label,
          trailing: residue.conservation.toStringAsFixed(2),
          labelKey: const ValueKey<String>('constraint-level'),
        ),
        if (explanation) ...<Widget>[
          const SizedBox(height: 12),
          _explanationOf(theme, length),
        ],
        const SizedBox(height: 16),
        Text(
          'Substitutions · ln p(aa)/p(WT)',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        // Clamped at both ends, and said at both: a residue where every change
        // scores below −10 draws every bar empty.
        ScoreScale(
          low: '−10 or lower',
          high: '0 or higher',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        for (int k = 0; k < visible.length; k++) ...<Widget>[
          // Rows skipped between two shown ones: the ranking is not contiguous
          // here, and a reader should not take the next row for the next rank.
          if (k > 0 && visible[k] != visible[k - 1] + 1)
            Padding(
              key: ValueKey<String>('substitution-gap-${visible[k]}'),
              padding: const EdgeInsets.only(left: 6, top: 1, bottom: 1),
              child: _Gap(colour: bar),
            ),
          SubstitutionBar(
            score: ranked[visible[k]],
            native: ranked[visible[k]].aminoAcid == residue.wildtype,
            // The reader's mark, in the accent the mask that asked was
            // outlined in: on the bar alone, never on its letter or number.
            color: ranked[visible[k]].aminoAcid == pick
                ? theme.colorScheme.primary
                : bar,
            reported: reported[ranked[visible[k]].aminoAcid],
            picked: ranked[visible[k]].aminoAcid == pick,
          ),
        ],
        if (expanded || hidden.isNotEmpty)
          TextButton(
            key: const ValueKey<String>('constraint-expand'),
            onPressed: onExpand,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
              expanded
                  ? 'Show top six'
                  : '${hidden.length} more · all ≤ '
                        '${formatScore(ranked[hidden.first].score)}',
            ),
          ),
        // What the residue is beyond its name and its scores, where it is
        // anything: its bridge, or the piece it goes with.
        if (residue.facts case final String facts) ...<Widget>[
          Divider(height: 12, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 6),
          Text(
            facts,
            key: const ValueKey<String>('constraint-facts'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        ?observedEvidence,
      ],
    );
  }
}

/// One amino acid's row in the residue panel.
class SubstitutionBar extends StatelessWidget {
  const SubstitutionBar({
    required this.score,
    required this.native,
    required this.color,
    this.reported,
    this.picked = false,
    super.key,
  });
  final SubstitutionScore score;
  final bool native;
  final Color color;

  /// The most severe ClinVar group recorded for this change, if any.
  final ClinVarGroup? reported;

  /// Whether this is the change the reader guessed ESM-2 ranks first, which
  /// the caller marks by [color] and a screen reader hears.
  final bool picked;

  @override
  Widget build(BuildContext context) => ScoreBar(
    label: score.aminoAcid,
    fraction: score.barFraction,
    value: formatScore(score.score),
    native: native,
    color: color,
    valueKey: ValueKey<String>('substitution-score-${score.aminoAcid}'),
    // A pick at the floor of the scale has an empty bar; its track carries
    // the mark there.
    trackOpacity: picked ? 0.3 : 0.1,
    tag: reported == null
        ? null
        : ClinVarDot(
            key: ValueKey<String>('substitution-clinvar-${score.aminoAcid}'),
            group: reported!,
            size: 9,
          ),
    semanticsLabel:
        '${score.aminoAcid}${native ? ', wild type' : ''}, '
        'score ${score.score.toStringAsFixed(3)}'
        '${reported == null ? '' : ', ClinVar ${reported!.label}'}'
        '${picked ? ', your pick' : ''}',
  );
}

/// What ⓘ opens, the same over the question as over the ranking: how the
/// scores were made, and what the constraint is.
Widget _explanationOf(ThemeData theme, int length) => Text(
  // The count was insulin's 109 for every protein.
  'ESM-2 650M masked marginals, precomputed: this position masked, '
  'all 20 amino acids scored against the other '
  '${grouped(length - 1)}. Score = ln p(aa)/p(WT), so WT is 0. '
  'Constraint = 1 − entropy of that prediction, min–max scaled '
  'within this protein.',
  key: const ValueKey<String>('constraint-explanation'),
  style: theme.textTheme.bodySmall,
);

/// The question that stands in the ranking's place while the reader is
/// guessing: which of the residue's changes ESM-2 ranks first. Everything the
/// sheet would say of the residue waits behind it, its level and its ClinVar
/// records too, which name changes people carry; one tap is the answer, and
/// the ranking it is checked against comes in where this was.
class _Guess extends StatelessWidget {
  const _Guess({
    required this.residue,
    required this.length,
    required this.explanation,
    required this.onAnswer,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool explanation;
  final ValueChanged<String?> onAnswer;

  /// The least a tile is, a thumb's target, and the room between two.
  static const double _tile = 44;
  static const double _gap = 4;

  /// Tiles to a row: as many as fit of ten, seven or five, so the twenty fall
  /// into two, three or four rows and never leave one hanging alone.
  static int _across(double width) {
    for (final int across in const <int>[10, 7]) {
      if (width >= across * _tile + (across - 1) * _gap) {
        return across;
      }
    }
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        if (explanation) ...<Widget>[
          _explanationOf(theme, length),
          const SizedBox(height: 16),
        ],
        Semantics(
          header: true,
          child: Text(
            'Which change does ESM-2 rank first?',
            key: const ValueKey<String>('guess-question'),
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints bounds) {
            final int across = _across(bounds.maxWidth);
            final double side =
                (bounds.maxWidth - (across - 1) * _gap) / across;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: <Widget>[
                // In the colour key's order, so the twenty read as the
                // chemistries the grid is coloured by.
                for (final String code in ChemistryKey.codes.split(''))
                  _GuessTile(
                    code: code,
                    side: side,
                    native: code == residue.wildtype,
                    onTap: () => onAnswer(code),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey<String>('guess-skip'),
          onPressed: () => onAnswer(null),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, 40),
          ),
          child: const Text('Show scores'),
        ),
      ],
    );
  }
}

/// One amino acid offered as the guess: its letter on its chemistry's colour,
/// as the grid draws it. The residue's own completes the twenty but cannot be
/// picked, being no change, and says so.
class _GuessTile extends StatelessWidget {
  const _GuessTile({
    required this.code,
    required this.side,
    required this.native,
    required this.onTap,
  });
  final String code;
  final double side;
  final bool native;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fill = context.anatomyColors.forResidue(code);
    final Color ink = native
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.surface;
    final Widget face = Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: native ? fill.withValues(alpha: 0.22) : fill,
        borderRadius: BorderRadius.circular(10),
      ),
      // Scaled down rather than cut where type is turned up past what a tile
      // holds: the letter is already the size of a heading.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              code,
              style: TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 22,
                height: 1,
                color: ink,
              ),
            ),
            if (native) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                'WT',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: AppTypography.sansFamily,
                  fontSize: 10,
                  height: 1,
                  color: ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !native,
      label: '${AminoAcids.nameOf(code)}${native ? ', wild type' : ''}',
      onTap: native ? null : onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey<String>('guess-tile-$code'),
        behavior: HitTestBehavior.opaque,
        onTap: native ? null : onTap,
        excludeFromSemantics: true,
        child: face,
      ),
    );
  }
}

/// A vertical ellipsis, drawn rather than typed: rows of the ranking skipped
/// between two shown ones. Three dots in the letter column, no taller than a
/// line of type.
class _Gap extends StatelessWidget {
  const _Gap({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++)
          Container(
            width: 2.5,
            height: 2.5,
            margin: const EdgeInsets.symmetric(vertical: 1.25),
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
      ],
    ),
  );
}
