// SPDX-FileCopyrightText: 2018-2023 Lukas Zronek
// SPDX-License-Identifier: BSD-2-Clause
//
// SSHAskpass.swift
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

import Foundation

class SSHAskpass {

    static let shared = SSHAskpass()

    // SSH_ASKPASS_PROMPT (OpenSSH 8.4+): confirm, none, or unset for text input
    enum PromptType {
        case input
        case confirmation
        case information
    }

    var message = String()
    var type:PromptType = PromptType.input
    // first user@host in the prompt text, a username hint for Password AutoFill
    var accountHint: String?

    func setup(message: String, promptEnv: String?) {
        self.message = message

        switch promptEnv {
        case "confirm": self.type = PromptType.confirmation
        case "none": self.type = PromptType.information
        default: self.type = PromptType.input
        }

        if let range = message.range(of: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+", options: .regularExpression) {
            self.accountHint = String(message[range])
        }
    }
}
