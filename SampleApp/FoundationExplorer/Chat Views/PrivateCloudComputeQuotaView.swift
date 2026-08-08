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

import SwiftUI
import FoundationModels

/// Private Cloud Compute doesn't have a token-counted context window the way
/// the on-device model does — it has a 32K-token context size and a daily
/// request quota instead. Reusing the on-device "Context Window: X/Y tokens"
/// UI for PCC would be wrong on both counts, so this shows PCC's own status
/// instead, following the pattern Apple documents at
/// https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
struct PrivateCloudComputeQuotaView: View {
  private let model = PrivateCloudComputeLanguageModel()
  @State private var contextSize: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let contextSize {
        Text("Context size: \(contextSize) tokens (quota-based, not counted per message).")
      } else {
        Text("Context size: quota-based, not counted per message.")
      }
      if model.quotaUsage.isLimitReached {
        Text("Usage limit exceeded.")
          .foregroundStyle(.red)
      } else if case .belowLimit(let info) = model.quotaUsage.status, info.isApproachingLimit {
        Text("Nearing usage limit.")
          .foregroundStyle(.orange)
      }
      if let suggestion = model.quotaUsage.limitIncreaseSuggestion {
        Button("Show Upgrade Options") {
          suggestion.show()
        }
      }
    }
    .task {
      // contextSize is fetched from the server, unlike the on-device model's
      // synchronous, local contextSize.
      contextSize = try? await model.contextSize
    }
  }
}

#Preview {
  PrivateCloudComputeQuotaView()
    .padding()
}
