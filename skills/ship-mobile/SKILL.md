---
name: ship-mobile
description: >-
  Ship an Expo mobile app's store listing and binary with the ship-mobile
  command, without spending an EAS build credit unless a cloud build is
  explicitly requested. Use when the user says ship, release, upload, submit,
  push metadata, send to TestFlight, or publish an iOS or Android app, or
  asks to update App Store or Play Store listing text, in any Expo project.
---

# Ship mobile

The command is `ship-mobile`. Run it from the Expo project you want to ship, the folder that contains `eas.json` and `store.config.json`. The source of this command is the ship-mobile repo, not the app repo.

## Rules

1. Preview first: run `ship-mobile --dry-run` with the same flags before the real run. Show the user the commands.
2. Never pass `--cloud` unless the user explicitly asks for an EAS cloud build. Say it spends one build credit per platform and ask for a yes. Then run `ship-mobile --cloud --yes`.
3. Do not build when only the store text changed. Use `--metadata-only`. It is App Store only.
4. If `ship-mobile` is not found, run `./install.sh` from the ship-mobile repo.

## Default

`ship-mobile`

Pushes `store.config.json`, then submits the latest finished production iOS build. No compile. No EAS build credit.

Android: `ship-mobile --platform android`. It submits the build only. EAS Metadata has no Play support, so the Play listing text is edited in Play Console.
Both: `ship-mobile --platform all`
Another eas.json profile: `ship-mobile --profile preview`

## New binary

Compile on this machine. No EAS build credit. iOS needs Xcode. Android needs the Android SDK.

`ship-mobile --local`
`ship-mobile --platform android --local`

## Cloud build

`ship-mobile --cloud --yes`, only after rule 2.

## Listing text only

`ship-mobile --metadata-only`

## Failures

| Message | Fix |
| --- | --- |
| `Not logged in to EAS` | Tell the user to run `! npx eas-cli login`. |
| `No store.config.json` | `npx eas-cli metadata:pull`, then review the file. |
| `No eas.json found` | Wrong folder. `cd` into the Expo app. |
| Submit finds no build | No finished build on EAS. Offer `--local`. Offer `--cloud` only as a paid option. |

## After it finishes

The command uploads the binary. It does not press Submit for Review. Tell the user to wait for processing, select the build on the version, and send it to review in App Store Connect or Play Console.
