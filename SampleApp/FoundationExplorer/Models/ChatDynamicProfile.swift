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
#if !targetEnvironment(simulator)
// In this Xcode 27 beta, Xcode's explicit-module build can't resolve either
// overlay module for the Simulator destination (device destinations build
// fine), so the built-in Vision and Spotlight tools are device-only here.
import _Vision_FoundationModels
import _CoreSpotlight_FoundationModels
#endif

/// Composes instructions, tools, and a per-mode model choice into a single
/// reusable profile. `ChatView` hands this to `LanguageModelSession(profile:)`
/// instead of picking a `LanguageModel` up front (see `ModelProvider.swift`
/// from Lesson 1) — the profile itself decides which model backs each turn.
///
/// - `.quickReply` uses the on-device model and can call `SwitchModeTool` to
///   escalate.
/// - `.deepReasoning` swaps in `PrivateCloudComputeLanguageModel` with
///   `reasoningLevel` (set from Settings) for turns that need more careful
///   thought.
///
/// Because both branches back the same `LanguageModelSession`, switching modes
/// mid-conversation keeps the transcript intact — this is what lets one model
/// hand off to another sequentially, in the middle of a single user request.
struct ChatDynamicProfile: LanguageModelSession.DynamicProfile {
  let state: ChatState
  let instructions: String?
  let useFrameworkHistoryManagement: Bool
  let reasoningLevel: ContextOptions.ReasoningLevel

  var body: some DynamicProfile {
    if useFrameworkHistoryManagement {
      modeProfile
        .summarizeHistory(entryThreshold: 10, model: SystemLanguageModel.default)
        .rollingWindow(entries: 10)
        .droppingCompletedToolCalls()
    } else {
      modeProfile
    }
  }

  /// Falls back to `.quickReply` when Private Cloud Compute isn't available —
  /// defense in depth alongside the check in `SwitchModeTool.call(arguments:)`,
  /// since building a profile backed by an unavailable `PrivateCloudComputeLanguageModel`
  /// traps instead of throwing a catchable error.
  private var effectiveMode: ChatMode {
    if state.mode == .deepReasoning, PrivateCloudComputeLanguageModel.unavailableReasonDescription != nil {
      return .quickReply
    }
    return state.mode
  }

  @LanguageModelSession.DynamicProfileBuilder
  private var modeProfile: some DynamicProfile {
    switch effectiveMode {
    case .quickReply:
      Profile {
        if let instructions {
          Instructions { instructions }
        }
        SwitchModeTool(state: state)
        #if !targetEnvironment(simulator)
        BarcodeReaderTool()
        OCRTool()
        SpotlightSearchTool()
        #endif
        AppSkills.makeSkills(activations: state.skillActivations)
      }
    case .deepReasoning:
      Profile {
        if let instructions {
          Instructions { instructions }
        }
        SwitchModeTool(state: state)
        #if !targetEnvironment(simulator)
        BarcodeReaderTool()
        OCRTool()
        SpotlightSearchTool()
        #endif
        AppSkills.makeSkills(activations: state.skillActivations)
      }
      .model(PrivateCloudComputeLanguageModel())
      .reasoningLevel(reasoningLevel)
    }
  }
}
