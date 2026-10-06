---
name: ship-mobile
description: >-
  Ship any Expo mobile app's store listing and binary without spending an EAS
  build credit unless a cloud build is explicitly requested. Use when the user
  says ship, release, upload, or submit an iOS or Android app, App Store
  metadata, or Play Store metadata, in any project.
---

# Ship mobile

The command is `ship-mobile`. Run it from the Expo project you want to ship, the folder that contains `eas.json` and `store.config.json`. The source of this command is the ship-mobile repo, not the app repo.

## Default

`ship-mobile`

Pushes `store.config.json`, then submits the latest finished production iOS build. No compile. No EAS build credit.

Android: `ship-mobile --platform android`
Both: `ship-mobile --platform all`

## New binary

Compile on this machine. No EAS build credit. iOS needs Xcode. Android needs the Android SDK.

`ship-mobile --local`
`ship-mobile --platform android --local`

## Cloud build

Only when the user explicitly asks for an EAS cloud build. Say that it spends one build credit per platform, then run:

`ship-mobile --cloud`

## Listing text only

`ship-mobile --metadata-only`

Do not build when only the store text changed.

## Preview

`ship-mobile --dry-run`

## After it finishes

The command uploads the binary. It does not press Submit for Review. Tell the user to wait for processing, select the build on the version, and send it to review in App Store Connect or Play Console.
