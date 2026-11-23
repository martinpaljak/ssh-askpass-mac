// SPDX-FileCopyrightText: 2018-2023 Lukas Zronek
// SPDX-FileCopyrightText: 2025-2026 Martin Paljak
// SPDX-License-Identifier: BSD-2-Clause
//
// ViewController.swift
// This file is part of ssh-askpass-mac
//
// Copyright (c) 2018-2022, Lukas Zronek
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Cocoa

// Calls onHold(true) on mouse down and onHold(false) on release
class HoldButton: NSButton {
    var onHold: ((Bool) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onHold?(true)
        super.mouseDown(with: event) // tracks until the mouse is released
        onHold?(false)
    }
}

class ViewController: NSViewController {
    
    @IBOutlet weak var infoTextField: NSTextField!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var okButton: NSButton!

    let sshAskpass = SSHAskpass.shared
    var accountField: NSTextField?
    var saveCheckBox: NSButton?
    // the account the password field was pre-filled for
    var storedAccount: String?
    // lies over the password field and shows its text while the eye is held
    var plainTextField: NSTextField?
    var passwordRow: NSStackView?

    var password: String {
        return passwordTextField.stringValue
    }
    var timeout = 0
    var timer: Timer?
    var cancelTitle = "Cancel"

    override func viewWillAppear() {
        super.viewWillAppear()
        fitWindow()
        view.window?.center()
    }

    // The window takes the size of its content, keeping its top edge: it
    // never keeps the storyboard size or the size before a field was hidden.
    func fitWindow() {
        guard let window = view.window else {
            return
        }
        view.layoutSubtreeIfNeeded()
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: view.fittingSize))
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true)
    }

    override func viewDidAppear() {
        // set first responder to allow closing window with escape key
        switch self.sshAskpass.type {
        case .confirmation, .information:
            self.view.window?.makeFirstResponder(cancelButton)
        case .input:
            self.view.window?.makeFirstResponder(passwordTextField)
        }
    }

    // Handle tab key, even if navigation disabled in settings.
    override func keyDown(with event: NSEvent) {
        let switchers: [UInt16] = [48, 123, 124] // tab, left arrow, right arrow
        guard switchers.contains(event.keyCode) else {
            super.keyDown(with: event)
            return
        }

        if (self.sshAskpass.type == .confirmation) {
            if self.timeout > 0 {
                timer?.invalidate()
                timer = nil
                cancelButton.title = cancelTitle
            }
            if self.view.window?.firstResponder === cancelButton {
                self.view.window?.makeFirstResponder(okButton)
                cancelButton.keyEquivalent = ""
                okButton.keyEquivalent = "\r"
            } else {
                self.view.window?.makeFirstResponder(cancelButton)
                okButton.keyEquivalent = ""
                cancelButton.keyEquivalent = "\r"
            }
        }
    }

    func startCountdown() {
        updateCounter() // Set the initial title

        // Schedule a timer to update the countdown every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.timeout -= 1
            if self.timeout <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.cancel(self) // Cancel the dialog when timeout reaches zero
            } else {
                self.updateCounter()
            }
        }
    }

    // SSH_ASKPASS_TIMEOUT: seconds until the dialog cancels itself
    func startCountdownIfAsked() {
        if let timeoutString = ProcessInfo.processInfo.environment["SSH_ASKPASS_TIMEOUT"],
           let timeoutValue = Int(timeoutString), timeoutValue > 0 {
            self.timeout = timeoutValue
            startCountdown()
        }
    }

    func updateCounter() {
        cancelButton.title = "\(cancelTitle) (in \(timeout)s)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !sshAskpass.message.isEmpty {
            infoTextField.stringValue = sshAskpass.message
        }
        switch self.sshAskpass.type {
        case .confirmation:
            passwordTextField.isHidden = true
            okButton.keyEquivalent = "" // reset default behaviour
            cancelButton.keyEquivalent = "\r" // set to return key
            startCountdownIfAsked()
        case .input:
            // Password AutoFill: the user picks the account from Passwords.
            // defaults write com.hardssh.ssh-askpass-mac autoFill -bool false
            let autoFill = UserDefaults.standard.object(forKey: "autoFill") as? Bool ?? true
            addRevealButton()
            if autoFill {
                passwordTextField.contentType = .password
                // room for the Passwords AutoFill popup that opens below the field
                if let row = passwordRow, let stack = row.superview as? NSStackView {
                    stack.setCustomSpacing(44, after: row)
                }
            }
            // "Save in keychain" and the pre-fill. Off with:
            // defaults write com.hardssh.ssh-askpass-mac keychain -bool false
            if UserDefaults.standard.object(forKey: "keychain") as? Bool ?? true {
                addSaveControls(account: sshAskpass.accountHint ?? "", autoFill: autoFill)
            }
        case .information:
            okButton.isHidden = true
            cancelTitle = "Close"
            cancelButton.title = cancelTitle
            passwordTextField.isHidden = true
            okButton.keyEquivalent = "" // reset default behaviour
            cancelButton.keyEquivalent = "\r" // set to return key
            startCountdownIfAsked()
        }
    }

    @IBAction func cancel(_ sender: Any) {
        timer?.invalidate() // Stop the timer
        exit(1)
    }
    
    // Unticked "Save in keychain" checkbox on the left of the button row;
    // ticking it reveals the user@host field above the password, pre-filled
    // from the prompt text if found. A value saved for that account only
    // pre-fills the password field.
    func addSaveControls(account: String, autoFill: Bool) {
        // the password field, or its row with the eye
        let password: NSView = passwordRow ?? passwordTextField
        guard let stack = password.superview as? NSStackView,
              let index = stack.arrangedSubviews.firstIndex(of: password),
              let buttons = cancelButton.superview as? NSStackView,
              let buttonArea = buttons.superview as? NSStackView else {
            return
        }
        // pre-filled: saved already, so the box starts ticked; unticking it
        // and pressing OK deletes the entry
        if let stored = loadPassword(account: account) {
            passwordTextField.stringValue = stored
            storedAccount = account
        }
        let saved = storedAccount != nil
        let checkBox = NSButton(checkboxWithTitle: "Save in keychain", target: self, action: #selector(saveChanged(_:)))
        checkBox.state = saved ? .on : .off
        // a new row [checkbox ... Cancel OK] in place of the buttons
        buttonArea.removeArrangedSubview(buttons)
        buttons.removeFromSuperview()
        let buttonRow = NSStackView(views: [checkBox, buttons])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonArea.addArrangedSubview(buttonRow)
        buttonRow.widthAnchor.constraint(equalTo: buttonArea.widthAnchor).isActive = true
        checkBox.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        buttons.setContentHuggingPriority(.required, for: .horizontal)
        saveCheckBox = checkBox

        let field = NSTextField(string: account)
        field.placeholderString = "user@host"
        field.isHidden = !saved
        // above the password, as in a login form
        stack.insertArrangedSubview(field, at: index)
        if autoFill {
            field.contentType = .username
        }
        field.widthAnchor.constraint(equalTo: password.widthAnchor).isActive = true
        accountField = field
    }

    // A row [password field][eye] in place of the password field, and a plain
    // field over the password field that shows the text while the eye is
    // held. The password field keeps focus and the value.
    func addRevealButton() {
        guard let stack = passwordTextField.superview as? NSStackView,
              let index = stack.arrangedSubviews.firstIndex(of: passwordTextField) else {
            return
        }
        let plain = NSTextField(string: "")
        plain.isEditable = false
        plain.isSelectable = false
        plain.isBezeled = true
        plain.bezelStyle = .squareBezel
        plain.drawsBackground = true
        plain.backgroundColor = .textBackgroundColor
        plain.textColor = .textColor
        plain.font = passwordTextField.font
        plain.isHidden = true
        plainTextField = plain

        let eye = HoldButton(image: NSImage(systemSymbolName: "eye", accessibilityDescription: "Hold to show password")!,
                             target: nil, action: nil)
        eye.isBordered = false
        eye.toolTip = "Hold to show password"
        eye.onHold = { [weak self] show in self?.reveal(show) }
        eye.setContentHuggingPriority(.required, for: .horizontal)

        stack.removeArrangedSubview(passwordTextField)
        passwordTextField.removeFromSuperview()
        let row = NSStackView(views: [passwordTextField, eye])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 6
        passwordTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.insertArrangedSubview(row, at: index)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        passwordRow = row

        plain.translatesAutoresizingMaskIntoConstraints = false
        // the empty plain field must not pull the password field narrow
        plain.setContentHuggingPriority(.init(1), for: .horizontal)
        plain.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        row.addSubview(plain) // not arranged: lies over the password field
        NSLayoutConstraint.activate([
            plain.leadingAnchor.constraint(equalTo: passwordTextField.leadingAnchor),
            plain.trailingAnchor.constraint(equalTo: passwordTextField.trailingAnchor),
            plain.topAnchor.constraint(equalTo: passwordTextField.topAnchor),
            plain.bottomAnchor.constraint(equalTo: passwordTextField.bottomAnchor),
        ])
    }

    // The password field only turns transparent: it keeps focus and value
    func reveal(_ show: Bool) {
        plainTextField?.stringValue = show ? passwordTextField.stringValue : ""
        plainTextField?.isHidden = !show
        passwordTextField.alphaValue = show ? 0 : 1
    }

    @objc func saveChanged(_ sender: NSButton) {
        accountField?.isHidden = sender.state != .on
        fitWindow()
    }

    @IBAction func ok(_ sender: Any) {
        if saveCheckBox?.state == .on, let account = accountField?.stringValue {
            savePassword(account: account, password: password)
        } else if let account = storedAccount {
            deletePassword(account: account)
        }
        print(password)
        exit(0)
    }

    // Internet password for ssh://host with account user, in the login
    // keychain. (The Passwords app needs an entitlement, see TODO.md.)
    func keychainItem(account: String) -> [CFString: Any]? {
        guard let at = account.lastIndex(of: "@"), at != account.startIndex,
              account.index(after: at) != account.endIndex else {
            return nil
        }
        return [
            kSecClass: kSecClassInternetPassword,
            kSecAttrProtocol: kSecAttrProtocolSSH,
            kSecAttrServer: String(account[account.index(after: at)...]),
            kSecAttrAccount: String(account[..<at]),
        ]
    }

    func loadPassword(account: String) -> String? {
        guard let item = keychainItem(account: account) else {
            return nil
        }
        let query = item.merging([kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]) { $1 }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // A failure only logs: the answer still goes to OpenSSH.
    func savePassword(account: String, password: String) {
        guard let item = keychainItem(account: account) else {
            FileHandle.standardError.write("ssh-askpass: not saved, account is not user@host\n".data(using: .utf8)!)
            return
        }
        let value: [CFString: Any] = [
            kSecValueData: password.data(using: .utf8)!,
            kSecAttrLabel: "SSH \(account)",
        ]
        var status = SecItemUpdate(item as CFDictionary, value as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(item.merging(value) { $1 } as CFDictionary, nil)
        }
        let text = SecCopyErrorMessageString(status, nil) as String? ?? "\(status)"
        FileHandle.standardError.write("ssh-askpass: save \(account): \(status) \(text)\n".data(using: .utf8)!)
    }

    func deletePassword(account: String) {
        guard let item = keychainItem(account: account) else {
            return
        }
        let status = SecItemDelete(item as CFDictionary)
        let text = SecCopyErrorMessageString(status, nil) as String? ?? "\(status)"
        FileHandle.standardError.write("ssh-askpass: delete \(account): \(status) \(text)\n".data(using: .utf8)!)
    }
}
