# Google Play store listing

Text for Play Console → Grow → Store presence → Main store listing. Play's limits are
in brackets. Keep every claim here
true to the shipped app, and change this file when the app changes.

## App name [30]

```
HelixPeek AI
```

## Short description [80]

```
One protein from gene to fold, with ESM-2, AlphaGenome and ClinVar on the way.
```

## Full description [4000]

```
HelixPeek AI walks one human protein from its gene to its folded structure, page by page, and lays the evidence on the molecule it describes.

THE WALK
Gene, mRNA, protein, mature chains, fold. Each page is drawn from the protein's GenBank record: exons and introns at their real lengths, splicing, translation, signal peptides and propeptides cleaved, disulfide bridges closed. The walk ends on the 3D structure, which folds in four steps from the deposited model: hydrophobic collapse, helices, strands, bridges.

THE EVIDENCE
• ESM-2 (650M): a constraint score for every residue and every substitution.
• AlphaGenome variant impact (AVI): predicted effect of single-base changes across the gene.
• ClinVar: submitted classifications, placed on the base or residue they name.
Tap a base or a residue to see what each source says about it, and compare the model scores against each other and against ClinVar.

BUILD ANY PROTEIN
Beyond the curated set, search the reviewed human proteome and build a protein on demand: its record, ESM-2, AlphaGenome and ClinVar tracks, and its fold (an experimental PDB entry chosen by rule, or AlphaFold DB's model where none passes). Progress shows step by step; a build can be stopped, kept or discarded.

ZOOM
From the body down to the gene's DNA: the organs where its RNA is raised (Expression Atlas), a specimen of the organ, a tissue section, the cell, the nucleus, a metaphase chromosome, the band, the gene's chromatin and its double helix.

PEPTIDE LANGUAGE MODEL
A small transformer trained on the curated proteins' peptides, played back from one recorded run, stage by stage: tokens, embeddings, attention, feed-forward, prediction, loss, backpropagation, AdamW updates, and 200 training steps. Every number on screen is the run's own.

PRIVACY
No account, no ads, no analytics, no tracking.

Sources: NCBI GenBank and ClinVar, UniProt, RCSB PDB, AlphaFold DB (CC BY 4.0), EMBL-EBI Expression Atlas (CC BY 4.0), Meta's ESM-2, and Google DeepMind's AlphaGenome, used under its Output Terms.

HelixPeek AI is for research and education. It is not a medical device and does not give medical advice or diagnoses.
```

## Console fields

- **App category:** Education. (Medical would bring Play's health-app declarations,
  and the app makes no clinical claim.)
- **Tags:** Science, Education.
- **Contact:** the developer email is required by Play and shown publicly; website
  optional (the GitHub Pages site works).
- **Privacy policy:** <https://gentipydev.github.io/helix-peek-mobile/privacy>.

## Graphics still needed

- App icon, 512 × 512 PNG, 32-bit, ≤ 1 MB.
- Feature graphic, 1024 × 500 PNG or JPEG, no alpha.
- Phone screenshots, 2–8, 16:9 or 9:16, each side 320–3840 px. Suggested set: the
  gene page, a residue sheet with ESM-2 and AVI, the ClinVar page, the fold, a zoom
  stop (organ or chromosome), the build card, a Peptide LM stage.
