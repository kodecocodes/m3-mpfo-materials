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

/// Lets the model escalate (or step back down) between the quick, on-device
/// reply mode and the deeper Private Cloud Compute reasoning mode declared in
/// `ChatDynamicProfile`. Calling this tool is what drives sequential model
/// usage: the fast model triages the request, then hands off to the deep
/// model mid-conversation with the transcript intact.
struct SwitchModeTool: Tool {
  let state: ChatState

  let name = "switchMode"
  let description = """
    Switches the assistant's operating mode. Call this with deepReasoning when \
    a request needs more careful reasoning than a quick reply can provide, or \
    with quickReply once deep reasoning is no longer needed.
    """

  @Generable
  struct Arguments {
    @Guide(description: "The mode to switch to.")
    var mode: ChatMode
  }

  func call(arguments: Arguments) async throws -> String {
    // Private Cloud Compute needs the com.apple.developer.private-cloud-compute
    // entitlement and an eligible device/account; using it while unavailable
    // traps instead of throwing, so this must be checked before ever setting
    // `state.mode = .deepReasoning`.
    if arguments.mode == .deepReasoning, let reason = PrivateCloudComputeLanguageModel.unavailableReasonDescription {
      return "Deep reasoning mode is unavailable right now (\(reason)). Staying in quick reply mode."
    }
    await MainActor.run {
      state.mode = arguments.mode
    }
    return "Switched to \(arguments.mode.rawValue) mode."
  }
}
