# ship-mobile

Push an Expo app's store listing and upload a binary from any project. The default run does not compile and does not spend an EAS build credit.

The app you ship needs `eas.json` and `store.config.json`. Run the command from that app's folder.

## Install

`~/.local/bin` needs to be on your `PATH`.

```bash
chmod +x ~/Desktop/my_projects/ship-mobile/bin/ship-mobile
ln -sfn ~/Desktop/my_projects/ship-mobile/bin/ship-mobile ~/.local/bin/ship-mobile
mkdir -p ~/.cursor/skills
ln -sfn ~/Desktop/my_projects/ship-mobile/.cursor/skills/ship-mobile ~/.cursor/skills/ship-mobile
```

The second link lets Cursor use this skill in every project.

## Use

```bash
cd ~/Desktop/my_projects/daily-skyline-ios
ship-mobile --dry-run
ship-mobile
```

| Command | What it does | EAS build credit |
| --- | --- | --- |
| `ship-mobile` | Push the listing, submit the latest production iOS build already on EAS | No |
| `ship-mobile --metadata-only` | Push the listing and stop | No |
| `ship-mobile --local` | Compile on this Mac, then submit. Needs Xcode | No |
| `ship-mobile --platform android` | Same default, for Play | No |
| `ship-mobile --platform android --local` | Compile on this machine. Needs the Android SDK | No |
| `ship-mobile --platform all` | iOS and Android | No, unless you also pass `--cloud` |
| `ship-mobile --cloud` | One EAS cloud build per platform, then submit | Yes, one per platform |

`--cloud` is the only form that spends build credits.

## After the upload

The command does not press Submit for Review. Wait until Apple or Google finishes processing the build, select it on the version, and send it to review.
