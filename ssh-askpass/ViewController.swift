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

class ViewController: NSViewController {
    
    @IBOutlet weak var infoTextField: NSTextField!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    @IBOutlet weak var keychainCheckBox: NSButtonCell!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    let sshKeychain = SSHKeychain.shared
    let sshAskpass = SSHAskpass.shared
    var timeout = 0
    var timer: Timer?
    
#if swift(>=4.2)
    let cautionName = NSImage.cautionName
#else
    let cautionName = NSImage.Name.caution
#endif

    override func viewDidAppear() {
        // set first responder to allow closing window with escape key
        switch self.sshAskpass.type {
        case .confirmation, .information:
            self.view.window?.makeFirstResponder(cancelButton)
        default: break // passwordTextField is first responder by default
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
                cancelButton.title = "Cancel"
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

    func updateCounter() {
        cancelButton.title = "Cancel (in \(timeout)s)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !sshAskpass.message.isEmpty {
            infoTextField.stringValue = sshAskpass.message
        }
        switch self.sshAskpass.type {
        case .confirmation:
            passwordTextField.isHidden = true
            if let controlView = keychainCheckBox.controlView {
                controlView.isHidden = true
            }

            okButton.keyEquivalent = "" // reset default behaviour
            cancelButton.keyEquivalent = "\r" // set to return key

            // Start the counter, if asked for
            if let timeoutString = ProcessInfo.processInfo.environment["SSH_ASKPASS_TIMEOUT"],
               let timeoutValue = Int(timeoutString) {
                self.timeout = timeoutValue
            }

            // Start the countdown if timeout is greater than zero
            if self.timeout > 0 {
                startCountdown()
            }
        case .passphrase:
            if sshAskpass.account.isEmpty {
                keychainCheckBox.state = NSControl.StateValue.off
                keychainCheckBox.isEnabled = false
            }
        case .password:
            if sshAskpass.account.isEmpty {
                keychainCheckBox.state = NSControl.StateValue.off
                keychainCheckBox.isEnabled = false
            }
        case .badPassphrase:
            break
        case .inputConfirmation:
            if let controlView = keychainCheckBox.controlView {
                controlView.isHidden = true
            }
        case .information:
            okButton.isHidden = true
            cancelButton.title = "Close"
            passwordTextField.isHidden = true
            if let controlView = keychainCheckBox.controlView {
                controlView.isHidden = true
            }
            okButton.keyEquivalent = "" // reset default behaviour
            cancelButton.keyEquivalent = "\r" // set to return key
        }
        
        if let obj = UserDefaults.standard.object(forKey: "useKeychain") {
            if let useKeychain = obj as? Bool {
                if (useKeychain) {
                    keychainCheckBox.state = NSControl.StateValue.on
                } else {
                    keychainCheckBox.state = NSControl.StateValue.off
                }
            }
        }
    }

    @IBAction func cancel(_ sender: Any) {
        timer?.invalidate() // Stop the timer
        exit(1)
    }
    
    @IBAction func ok(_ sender: Any) {
        if (sshAskpass.type == .passphrase || sshAskpass.type == .badPassphrase || sshAskpass.type == .password) && !sshAskpass.account.isEmpty && keychainCheckBox.state == NSControl.StateValue.on {
            let status = sshKeychain.add(account: sshAskpass.account, password: passwordTextField.stringValue)

            if status == errSecDuplicateItem {
                ask(messageText: "Warning", informativeText: "A passphrase for \"\(sshAskpass.account)\" already exists in the keychain.\nDo you want to replace it?", okButtonTitle: "Replace", completionHandler: { (result) in
                    if result == .alertFirstButtonReturn {
                        let status = self.sshKeychain.delete(account: self.sshAskpass.account)
                        if status == errSecSuccess {
                            self.ok(self)
                        } else {
                            self.keychainError(status: status)
                            return
                        }
                    }
                })
                return
            } else if status != errSecSuccess {
                keychainError(status: status)
                return
            }
        }
        print(passwordTextField.stringValue)
        exit(0)
    }
    
    @IBAction func useKeychainChanged(_ sender: NSButtonCell) {
        var useKeychain:Bool = false
        if (sender.state == NSControl.StateValue.on) {
            useKeychain = true
        }
        UserDefaults.standard.set(useKeychain, forKey: "useKeychain")
    }
    
    func keychainError(status: OSStatus) {
        error(messageText: "Keychain Error", informativeText: SecCopyErrorMessageString(status, nil)! as String)
    }
    
    func error(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.icon = NSImage(named: cautionName)
        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    func ask(messageText: String, informativeText: String, okButtonTitle: String, completionHandler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.icon = NSImage(named: cautionName)
        _ = alert.addButton(withTitle: okButtonTitle)
        _ = alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.view.window!, completionHandler: completionHandler)
    }
}
