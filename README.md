# ship-mobile

One command to push your store listing and upload your binary for an Expo app.

```bash
cd your-expo-app
ship-mobile --dry-run   # see exactly what would run
ship-mobile             # push listing, submit the latest build
```

`ship-mobile` wraps [EAS CLI](https://docs.expo.dev/eas/) into a small release pipeline. The default run does not compile anything and does not spend an EAS build credit.

```
lint listing ─▶ push listing ─▶ build (optional) ─▶ submit ─▶ you press
   iOS only        iOS only      --local / --cloud    binary    Submit for Review
```

## Why

Shipping an Expo app by hand means remembering four or five `eas` commands, their flags, and which of them cost money. `ship-mobile` puts them behind one command with safe defaults:

- **No surprise bills.** Only `--cloud` spends EAS build credits, and it asks first.
- **Preview first.** `--dry-run` prints every command and runs none of them.
- **Fails early.** It checks your login, `eas.json`, profile and local toolchain before it does any work.
- **Agent friendly.** It ships rules for Claude Code, Cursor, Codex, Gemini CLI, Copilot, Windsurf, Cline and Continue, so an AI assistant can run it with the same guardrails.

## Requirements

- macOS or Linux, with `bash` 3.2 or newer
- Node.js (the command runs EAS CLI through `npx`)
- An [Expo](https://expo.dev) account, logged in: `npx eas-cli login`
- In the app you ship: an `eas.json`, and a `store.config.json` for iOS listings
- Store credentials already set up in EAS, so submits can run non-interactively
- For `--local`: Xcode for iOS, the Android SDK (`ANDROID_HOME`) for Android

## Install

```bash
git clone https://github.com/murathudavendigar/ship-mobile.git
cd ship-mobile
./install.sh
```

The script links the command into `~/.local/bin`, and the skill into `~/.claude/skills` and `~/.cursor/skills`. Make sure `~/.local/bin` is on your `PATH`. The script warns you if it is not.

It is safe to run again. `./install.sh --uninstall` removes only the links it made, and it never overwrites a real file.

## Usage

Run it from inside your Expo app. It finds `eas.json` by walking up from the current folder.

| Command | What it does | EAS build credit |
| --- | --- | --- |
| `ship-mobile` | Push the iOS listing, submit the latest production iOS build already on EAS | No |
| `ship-mobile --metadata-only` | Push the iOS listing and stop | No |
| `ship-mobile --local` | Push the listing, compile on this machine, submit | No |
| `ship-mobile --platform android` | Submit the latest production Android build | No |
| `ship-mobile --platform all` | iOS and Android | No, unless you add `--cloud` |
| `ship-mobile --profile preview` | Use another `eas.json` profile instead of `production` | No |
| `ship-mobile --cloud` | One EAS cloud build per platform, then submit. Asks to confirm | **Yes, one per platform** |
| `ship-mobile --cloud --yes` | The same, without the prompt | **Yes, one per platform** |
| `ship-mobile --dry-run` | Add to any command to print it without running it | No |

### Options

| Option | Meaning |
| --- | --- |
| `--platform ios\|android\|all` | Which store to ship to. Default: `ios` |
| `--metadata-only` | Push the listing only |
| `--local` | Compile on this machine, then submit |
| `--cloud` | Compile on EAS, then submit. Spends build credits |
| `--profile NAME` | `eas.json` profile. Default: `production` |
| `--yes`, `-y` | Skip the `--cloud` confirmation |
| `--dry-run` | Print the commands without running them |
| `--version` | Print the version |

`--metadata-only`, `--local` and `--cloud` are mutually exclusive.

## What costs money

| Step | Where it runs | Build credit |
| --- | --- | --- |
| Listing lint and push | Your machine, talks to App Store Connect | No |
| `--local` build | Your machine | No |
| Submit | EAS | No. It uploads a file, it does not build |
| `--cloud` build | EAS servers | Yes |

[Expo's docs](https://docs.expo.dev/billing/faq/) confirm that local builds do not use your build quota. They do not list a separate quota for submits, so check your plan's usage page if you need a hard guarantee.

## Store support

| | iOS (App Store) | Android (Google Play) |
| --- | --- | --- |
| Listing text (`store.config.json`) | Yes, through [EAS Metadata](https://docs.expo.dev/eas/metadata/) | No. Edit it in Play Console |
| Upload a binary | Yes | Yes |

EAS Metadata only supports the App Store, so the listing push runs for iOS and never for Android. `--metadata-only --platform android` is an error. Google Play also requires the very first release of an app to be uploaded by hand in Play Console. Automated submits work after that.

## Profiles

`--profile` selects the `submit` profile for the listing and the upload, and the `build` profile for compiling. A profile you name must exist in each section the run uses. The default, `production`, is optional.

```json
{
  "build":  { "production": {}, "preview": {} },
  "submit": { "production": {}, "preview": {} }
}
```

## After the upload

`ship-mobile` does not press **Submit for Review**. That step is deliberate. Wait until Apple or Google finishes processing the build, select it on the version, and send it to review yourself.

`--local` writes the binary to `dist/` inside your app. Add `dist/` to that app's `.gitignore`.

## Use it with an AI assistant

The rules for assistants live in one file, `skills/ship-mobile/SKILL.md`. They tell the assistant to preview with `--dry-run` first, to never use `--cloud` without your explicit yes, and how to react to each failure message.

**Claude Code and Cursor** load it as a skill. `./install.sh` links it globally, once, for every project.

**Other assistants** read rule files from the project, so add them to your app:

```bash
./install.sh --project ~/code/my-expo-app
```

| Assistant | File written in your app |
| --- | --- |
| Codex, Cursor, Zed, and others that read `AGENTS.md` | `AGENTS.md` |
| Gemini CLI | `GEMINI.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Windsurf | `.windsurf/rules/ship-mobile.md` |
| Cline | `.clinerules/ship-mobile.md` |
| Continue | `.continue/rules/ship-mobile.md` |

In `AGENTS.md`, `GEMINI.md` and the Copilot file, the script adds one marked block and leaves the rest of your file alone. Re-running it updates that block. Files that are entirely ours are never overwritten if you already have one with the same name.

Pick some with `--only`, for example `./install.sh --project . --only agents,gemini`. Undo with `./install.sh --project . --uninstall`. These file formats follow each tool's documented convention, but only the file output is tested here, not each assistant.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `Not logged in to EAS` | `npx eas-cli login` |
| `No eas.json found` | Run it from inside the Expo app |
| `No store.config.json` | `npx eas-cli metadata:pull` |
| `Profile 'x' is not in the submit/build section` | Add the profile to `eas.json`, or fix the name |
| `--local iOS builds need Xcode` | Install Xcode, or use `--cloud` if you accept the credit |
| `--local Android builds need the Android SDK` | Install the SDK and set `ANDROID_HOME` |
| `--cloud spends build credits. Pass --yes` | There is no terminal to ask on. Add `--yes` |
| `EAS Metadata does not support Google Play` | Use `--platform ios` or `--platform all` |
| Submit finds no build | No finished build on EAS yet. Use `--local`, or `--cloud` if you accept the credit |

## Develop

```bash
test/run.sh
```

The tests are plain bash with a stubbed `npx`. They touch no store, need no network, and spend nothing. Please add a test with every behavior change. Run `shellcheck bin/ship-mobile install.sh test/run.sh` too if you have it.

Issues and pull requests are welcome.

## Disclaimer

`ship-mobile` is an independent project. It is not affiliated with or endorsed by Expo, Apple or Google. It runs EAS CLI on your behalf and uses your credentials, so read `bin/ship-mobile` before you trust it with a release. The command is one readable bash script.

## License

[MIT](LICENSE)
