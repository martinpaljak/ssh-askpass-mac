# ssh-askpass-mac

> Passphrase, confirmation and notice dialog for [OpenSSH](https://www.openssh.com) on macOS, with optional [keychain](https://support.apple.com/guide/mac-help/use-keychains-to-store-passwords-mchlf375f392/mac) storage for key passphrases.

> [!IMPORTANT]
> **ssh-askpass-mac is the work of [Lukas Zronek](https://github.com/lukas-zronek).**
> This is a fork of **[lukas-zronek/ssh-askpass-mac](https://github.com/lukas-zronek/ssh-askpass-mac)**, maintained by [Martin Paljak](https://github.com/martinpaljak) for [sudo-approve-agent](https://github.com/martinpaljak/pam-sudo-ssh).
> All credit for the app goes to Lukas; bugs in the changes below are mine.
> Screenshots and demo are from the original project.

OpenSSH runs the program in `$SSH_ASKPASS` when it needs input and has no terminal, or when `SSH_ASKPASS_REQUIRE=force`: a key passphrase, a password, a host key decision, or a yes/no for an agent key. ssh-askpass-mac shows the matching dialog and returns the answer the way OpenSSH expects. It was inspired by [ksshaskpass](https://github.com/KDE/ksshaskpass) and behaves like the keychain support macOS had before Sierra.

![screenshot](https://github.com/lukas-zronek/screenshots/blob/master/ssh-askpass-mac/passphrase-v3.png "Passphrase dialog")

Use it as the confirmation dialog for keys added with [ssh-add -c](https://man.openbsd.org/ssh-add.1) (RECOMMENDED):

![screenshot](https://github.com/lukas-zronek/screenshots/blob/master/ssh-askpass-mac/confirmation-v3.png "Confirmation dialog")

![demo](https://github.com/lukas-zronek/screenshots/blob/master/ssh-askpass-mac/passphrase-demo-v3.webp "Demo")

## Changes in this fork

* Monospace message font, so fingerprints and key details line up.
* `SSH_ASKPASS_TIMEOUT` cancels confirm and notice dialogs after N seconds, with a countdown on the button.
* Tab and the arrow keys move the default button between Cancel and OK in confirm dialogs.
* No Dock icon or menu bar, ever (`LSUIElement`). The window can't be minimized or resized.
* The dialog shows on the current Space, also over a full-screen app.
* Closing the window and Cmd+Q mean **cancel**. Before, the close button left the process hanging and Cmd+Q exited 0, which confirms.
* Keychain lookups only match items this app stored (service `SSH`). Before, a password prompt for `user@host` could pick up another app's item for the same account.
* The keychain checkbox is hidden when there is nothing to store the value under.
* Bundle ID `com.hardssh.ssh-askpass-mac`, Homebrew formula, `make` build with Developer ID signing.

## Install

The app goes to `/Applications/ssh-askpass.app`. Everything below assumes that path.

### Homebrew

```sh
brew tap martinpaljak/ssh-askpass-mac https://github.com/martinpaljak/ssh-askpass-mac
brew install --HEAD martinpaljak/ssh-askpass-mac/ssh-askpass-mac
rm -rf /Applications/ssh-askpass.app
ditto "$(brew --prefix)/opt/ssh-askpass-mac/ssh-askpass.app" /Applications/ssh-askpass.app
```

Homebrew can't write to `/Applications`, so you copy the app yourself, again after each `brew upgrade --fetch-HEAD`. The Homebrew build is signed ad hoc: macOS asks again for keychain access after each upgrade. Use `make` for a signed build.

### From source

Requires Xcode (the Command Line Tools alone are not enough; `make` finds `/Applications/Xcode.app` by itself).

```sh
git clone https://github.com/martinpaljak/ssh-askpass-mac.git
cd ssh-askpass-mac
make TEAMID=XXXXXXXXXX install
```

| Target | What it does |
|---|---|
| `make` | build `build/Release/ssh-askpass.app` |
| `make install` | build and copy to `/Applications` |
| `make verify` | check the signature, show the designated requirement |
| `make reuse` | check license and copyright information with [reuse](https://reuse.software) |
| `make clean` | remove `build/` |

`TEAMID` picks the "Developer ID Application" certificate of that Apple developer team; Xcode finds it in your keychain. The default is my team (`727L5NLWT4`), so without my certificate you MUST pass your own `TEAMID`, or `TEAMID=-` for an ad hoc signature.

> [!TIP]
> Sign it. macOS remembers "Always Allow" for a keychain item by the app's designated requirement. Ad hoc, that is the hash of one build, and every rebuild asks again. Signed, it is the bundle ID plus your team ID, which lasts across rebuilds.

### Set `SSH_ASKPASS` for your session

The Launch Agent sets `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE=force` with `launchctl setenv` at login, and restarts the system `ssh-agent` so it picks them up:

```sh
ln -s /Applications/ssh-askpass.app/Contents/Resources/com.hardssh.ssh-askpass-mac.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.hardssh.ssh-askpass-mac.plist
```

Restart your terminal app afterwards. Coming from the original app? Unload and remove `~/Library/LaunchAgents/at.zronek.lukas.ssh-askpass.plist` first.

Skip this if only one program needs the dialog: sudo-approve-agent, for example, sets `SSH_ASKPASS` in its own environment.

## How it is launched

OpenSSH runs `ssh-askpass "<prompt text>"`. The dialog type comes from `SSH_ASKPASS_PROMPT` first, then from the prompt text:

| `SSH_ASKPASS_PROMPT` | Prompt text (matched in this order) | Sent by | Dialog |
|---|---|---|---|
| `confirm` | anything | `ssh-agent` for keys added with `-c`, `ssh` with `AddKeysToAgent ask` | Confirm |
| `none` | anything | `ssh` while waiting for a FIDO key touch, sudo-approve-agent | Notice |
| unset or other | `Enter passphrase for key '<path>': ` | `ssh` | Passphrase |
| | `Enter passphrase for <path>: `, optionally with ` (will confirm each use)` | `ssh-add` | Passphrase |
| | `Bad passphrase, try again for <path>: ` | `ssh-add` | Passphrase, no keychain lookup |
| | `Allow use of key <path>?` | `ssh-agent` older than 8.4 | Confirm |
| | `Add key <path> (<comment>) to agent?` | `ssh` older than 8.4 with `AddKeysToAgent ask` | Confirm |
| | `The authenticity of host '<host>' can't be established.` | `ssh` | Text input: type `yes`, `no` or the fingerprint |
| | `(<user@host>) Password:` | `ssh`, keyboard-interactive | Password |
| | `<user@host>'s password: ` | `ssh`, password authentication | Password |
| | anything else, or no argument | | Text input, no keychain |

| Dialog | Buttons | Answer on stdout | Exit status |
|---|---|---|---|
| Passphrase, Password, Text input | Cancel, **OK** | OK: the typed text | OK: 0, otherwise 1 |
| Confirm | **Cancel**, OK | none | OK: 0, otherwise 1 |
| Notice | **Close** | none | always 1 |

* **Bold** is the default button (Return). In Confirm, Tab and the arrow keys move the default to OK and back.
* Esc, the window's close button, Cmd+Q and a timeout all mean cancel: exit 1.
* `SSH_ASKPASS_TIMEOUT=<seconds>` cancels Confirm and Notice dialogs after that time, with a countdown on the button. Moving the default button in Confirm stops the countdown. Other dialogs ignore it.
* OpenSSH kills the Notice dialog itself, for example when you touch the FIDO key.

### Keychain

Only Passphrase and Password dialogs use the keychain. The account is the key path (made absolute, symlinks resolved) or `user@host`:

* If the keychain has a value for the account, ssh-askpass-mac prints it and shows **no dialog** at all. `Bad passphrase` always shows the dialog.
* With "Remember passphrase in my keychain" ticked, OK stores the typed value as a generic password with service `SSH`, label `SSH: <account>`. If one exists, you are asked whether to replace it.
* The checkbox state is remembered. To turn it off by default:

```sh
defaults write com.hardssh.ssh-askpass-mac useKeychain -bool false
```

## Security

* Values go to the login keychain, with no app trusted. macOS asks before handing them out; "Always Allow" trusts this app for that item from then on. You SHOULD NOT click "Always Allow" unless the build is signed (see [From source](#from-source)).
* Use the Keychain Access app to move items to a separate keychain with auto-lock. ssh-askpass-mac finds them in any keychain.
* The typed value sits in the app's memory, and Swift gives no way to wipe it. A local administrator can read it out.

## Notes

With [Secure Keyboard Entry](https://support.apple.com/guide/terminal/use-secure-keyboard-entry-trml109/mac) on in Terminal.app, ssh-askpass-mac can't take focus. Click the dialog to type into it.

## License

[BSD 2-Clause](LICENSE), copyright (c) 2018-2023 Lukas Zronek, with changes copyright (c) 2025-2026 Martin Paljak. Every file carries SPDX information ([REUSE](https://reuse.software) 3.3); `make reuse` checks it.
