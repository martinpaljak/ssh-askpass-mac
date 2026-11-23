// SPDX-FileCopyrightText: 2018-2024 Lukas Zronek
// SPDX-FileCopyrightText: 2026 Martin Paljak
// SPDX-License-Identifier: BSD-2-Clause
//
// AppDelegate.swift
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

// A paste into the password field clears the clipboard afterwards, so the
// secret does not stay there. Cmd+V and the context menu both come through
// sendAction. Off with:
// defaults write com.hardssh.ssh-askpass-mac clearClipboard -bool false
@objc(AskpassApplication)
class AskpassApplication: NSApplication {
    override func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
        let editor = keyWindow?.firstResponder as? NSText
        let intoPassword = action == #selector(NSText.paste(_:)) && editor?.delegate is NSSecureTextField
        let handled = super.sendAction(action, to: target, from: sender)
        let clear = UserDefaults.standard.object(forKey: "clearClipboard") as? Bool ?? true
        if handled && intoPassword && clear {
            NSPasteboard.general.clearContents()
        }
        return handled
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let window = NSApp.windows.first {
            // show window always on top
            window.level = .modalPanel
            // show it on the current Space, also over a full-screen app
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            // Sets the window’s location to the center of the screen
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            // closing the window means cancel, not a process left waiting
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { _ in
                exit(1)
            }
        }
        // LSUIElement in Info.plist keeps the app out of the Dock and the menu bar
        NSApp.activate(ignoringOtherApps: true)
    }

    // Quit means cancel: NSApp.terminate exits 0, which confirms.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        exit(1)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

