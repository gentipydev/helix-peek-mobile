---
title: HelixPeek AI — Privacy Policy
---

# HelixPeek AI — Privacy Policy

Effective 19 November 2026.

HelixPeek AI ("the app") shows public scientific data about human proteins. It has no
accounts, advertising, analytics or crash-reporting SDKs, and it does not track you.

## What the app sends

- **An install id.** The first time you ask the app to build a protein, it makes a random
  128-bit id and stores it on your device. The id is sent with every build request, so
  only your phone can stop, keep or discard that build, and so the service can cap the
  number of builds one install makes in a day. The id doesn't name you and isn't linked
  to any other identifier. Uninstalling the app deletes it from your device.
- **What you ask for.** The names of the proteins and genes you open or search for are
  sent to our service, so it can return their data.
- **Network data.** Like any internet service, our hosting providers receive your IP
  address when the app connects. We use it only to limit request rates and to keep the
  service secure. We don't store it with the install id, and we don't use it to identify
  you.

The app never collects your name, email, contacts, location, photos or health data.

## Where the data goes

The service that answers the app is run on these providers, which process the data above
for us and for no other purpose:

- Render, which runs the API;
- Supabase, which stores the database and files;
- Modal, which runs protein builds.

We don't sell or share data with anyone else, and we don't use it for advertising. All
traffic is encrypted in transit (HTTPS).

## Retention

Build requests, with their install id, are kept while the protein they built is kept, and
in a spend log that limits the service's costs. Neither one is linked to a person. Data
cached on your device (up to 200 MB of public scientific data) stays there until you
uninstall the app.

## Children

The app is not directed at children under 13 and does not knowingly collect their data.

## Your choices

You can delete everything the app keeps on your device by uninstalling it. A build you
stopped can be discarded from the same phone. To ask about, or request deletion of,
build records tied to your install id, contact us below.

## Changes

If this policy changes, we'll update this page and its effective date.

## Contact

Open an issue at <https://github.com/gentipydev/helix-peek-mobile/issues>.
