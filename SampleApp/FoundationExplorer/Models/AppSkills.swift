/// Copyright (c) 2026 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import FoundationModels
import FoundationModelsUtilities

/// Two skills the model can activate just-in-time, showing both `Skill`
/// initializer styles from `foundation-models-utilities`:
/// - `swiftStyleGuide` is prompt-based — its content lands in the transcript
///   as tool output the first time it activates, and never needs to leave.
/// - `beginnerMode` is instructions-based and deactivatable — its content is
///   folded into the session's instructions while active, and the model can
///   remove it again once a request no longer needs beginner-level detail.
enum AppSkills {
  static func makeSkills(activations: SkillActivations) -> Skills {
    Skills(activations: activations) {
      Skill(
        name: "swift-style-guide",
        description: "Applies a short Swift style guide when the user asks for or reviews Swift code",
        prompt: """
          # Swift Style Guide

          - Prefer `let` over `var`; only use `var` when the value must change.
          - Name booleans as assertions: `isEnabled`, `hasChanges`, not `enabled`.
          - Avoid force-unwraps and force-casts outside of tests.
          - Keep functions small enough to read without scrolling.
          """
      )

      Skill(
        name: "beginner-mode",
        description: "Explains answers in beginner-friendly terms, avoiding jargon",
        instructions: """
          The user is new to programming. Explain concepts in plain language, \
          define any technical term the first time you use it, and prefer \
          short sentences over dense ones.
          """,
        allowsDeactivation: true
      )
    }
  }
}
