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
* The dialog type comes only from `SSH_ASKPASS_PROMPT`. The original guessed it from 7 patterns of OpenSSH's prompt text.
* The keychain only **pre-fills** the field. The original answered a matching prompt from the keychain with no dialog at all.
* Password AutoFill from the Passwords app, and an eye after the field that shows the text while you hold it.
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

OpenSSH runs `ssh-askpass "<prompt text>"` and sets `SSH_ASKPASS_PROMPT` (OpenSSH 8.4 and later). The variable alone picks the dialog; the prompt text is only shown:

| `SSH_ASKPASS_PROMPT` | Sent by | Dialog | Buttons | Answer on stdout | Exit status |
|---|---|---|---|---|---|
| `confirm` | `ssh-agent` for keys added with `-c`, `ssh` with `AddKeysToAgent ask` | Confirm | **Cancel**, OK | none | OK: 0, otherwise 1 |
| `none` | `ssh` while waiting for a FIDO key touch, sudo-approve-agent | Notice | **Close** | none | always 1 |
| unset or other | `ssh` and `ssh-add`: passphrases, passwords, the host key question | Text input | Cancel, **OK** | the typed text | OK: 0, otherwise 1 |

* **Bold** is the default button (Return). In Confirm, Tab and the arrow keys move the default to OK and back.
* Esc, the window's close button, Cmd+Q and a timeout all mean cancel: exit 1.
* `SSH_ASKPASS_TIMEOUT=<seconds>` cancels Confirm and Notice dialogs after that time, with a countdown on the button. Moving the default button in Confirm stops the countdown. Other dialogs ignore it.
* OpenSSH kills the Notice dialog itself, for example when you touch the FIDO key.
* Text input is always a password field. For the host key question you type `yes`, `no` or the fingerprint blind; hold the eye to check it.

### Text input

* **Eye** after the field: hold it to show the text, release to hide it. Focus stays in the password field.
* **Password AutoFill**: the field offers entries from the Passwords app ("Passwords..." under the field). macOS never offers to save from the dialog: add SSH entries in Passwords yourself, with a title such as `SSH test.example`. To turn AutoFill off, and with it the space the popup needs under the field:

```sh
defaults write com.hardssh.ssh-askpass-mac autoFill -bool false
```

* **Save in keychain** (left of the buttons, unticked): ticking it shows an account field above the password, pre-filled with the first `user@host` in the prompt text. OK then saves the value to the login keychain as an internet password for `ssh://host`, account `user`. The Passwords app doesn't show these; see [TODO.md](TODO.md).
* Next time a prompt names the same `user@host`, the saved value **pre-fills** the field, and the box starts ticked. The dialog always shows, and Cancel always works. Untick the box and press OK to delete the saved value.

## Security

* No prompt is ever answered without the dialog.
* Saved values go to the login keychain, readable by the app that saved them. Rebuilds with the same `TEAMID` count as the same app; ad hoc builds ask again each time (see [From source](#from-source)).
* The typed value sits in the app's memory, and Swift gives no way to wipe it. A local administrator can read it out.

## Notes

With [Secure Keyboard Entry](https://support.apple.com/guide/terminal/use-secure-keyboard-entry-trml109/mac) on in Terminal.app, ssh-askpass-mac can't take focus. Click the dialog to type into it.

## License

[BSD 2-Clause](LICENSE), copyright (c) 2018-2023 Lukas Zronek, with changes copyright (c) 2025-2026 Martin Paljak. Every file carries SPDX information ([REUSE](https://reuse.software) 3.3); `make reuse` checks it.
