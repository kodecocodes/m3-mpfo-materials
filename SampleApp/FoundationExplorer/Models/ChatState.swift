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

import Foundation
import FoundationModels
import FoundationModelsUtilities

/// The two operating modes `ChatDynamicProfile` can resolve to. `@Generable` so
/// it can be used directly as a `Tool` argument type in `SwitchModeTool`.
@Generable
enum ChatMode: String, Sendable {
  case quickReply
  case deepReasoning

  var title: String {
    switch self {
    case .quickReply: return "Quick Reply (on-device)"
    case .deepReasoning: return "Deep Reasoning (Private Cloud Compute)"
    }
  }
}

/// Shared between `ChatDynamicProfile` and `SwitchModeTool` so the model can
/// switch its own operating mode mid-conversation — the same `LanguageModelSession`
/// keeps its history across the switch. Marked `@unchecked Sendable` because
/// `SwitchModeTool.call(arguments:)` runs off the main actor; it always hops
/// back to the main actor before touching `mode`, so mutation stays serialized.
@Observable
final class ChatState: @unchecked Sendable {
  var mode: ChatMode = .quickReply

  /// Tracks which of `AppSkills`'s skills the model has activated. Passed to
  /// `Skills(activations:)` in `ChatDynamicProfile`; conforms to `Observable`
  /// itself, so a chip row can display active skills without extra plumbing.
  let skillActivations = SkillActivations()
}
