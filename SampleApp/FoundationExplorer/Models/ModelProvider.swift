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
import Security
import FoundationModels
import FoundationModelsUtilities
import ClaudeForFoundationModels

/// The language models Foundation Explorer can back a session with. Every case
/// conforms to the same `LanguageModel` protocol, so switching providers never
/// changes how the rest of the app talks to `LanguageModelSession`.
enum ModelProvider: String, CaseIterable, Identifiable {
  case onDevice
  case privateCloudCompute
  case claude
  case localServer

  var id: String { rawValue }

  var title: String {
    switch self {
    case .onDevice: return "On-Device"
    case .privateCloudCompute: return "Private Cloud Compute"
    case .claude: return "Claude (Anthropic)"
    case .localServer: return "Local Server"
    }
  }

  var caption: String {
    switch self {
    case .onDevice:
      return "Runs entirely on this device. No network access, no account required."
    case .privateCloudCompute:
      return "A larger server-side Apple model with a 32K-token context and adjustable reasoning. Free while your app has fewer than 2M first-time downloads; higher limits with iCloud+. Usage is quota-based, not token-counted."
    case .claude:
      return "Anthropic's Claude models, reached through the official ClaudeForFoundationModels package. Requires an Anthropic API key."
    case .localServer:
      return "Any server that speaks the OpenAI-compatible chat completions API, such as a local Ollama or LM Studio instance."
    }
  }

  static let defaultLocalServerURLString = "http://localhost:11434/v1"

  /// `nil` when this provider is ready to use right now; otherwise a message
  /// explaining why. `.claude` and `.localServer` don't have a meaningful
  /// pre-flight check (a missing key or unreachable URL only surfaces once
  /// you try to send a prompt), but `.onDevice` and `.privateCloudCompute`
  /// both have a runtime availability API that must be checked *before*
  /// constructing a session — using either while unavailable can trap
  /// instead of throwing a catchable error, so this must be checked
  /// per-provider rather than once at app launch.
  var unavailableReason: String? {
    switch self {
    case .onDevice:
      return SystemLanguageModel.onDeviceUnavailableReasonDescription
    case .privateCloudCompute:
      return PrivateCloudComputeLanguageModel.unavailableReasonDescription
    case .claude, .localServer:
      return nil
    }
  }
}

extension SystemLanguageModel {
  /// A human-readable reason the on-device model can't be used right now, or
  /// `nil` when it's available. Mirrors `ModelUnavailableView`'s per-reason
  /// copy, since both describe the same `UnavailableReason` cases.
  static var onDeviceUnavailableReasonDescription: String? {
    switch SystemLanguageModel.default.availability {
    case .available:
      return nil
    case .unavailable(.deviceNotEligible):
      return "Apple Intelligence is not available on this device."
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Apple Intelligence is available, but not enabled on this device."
    case .unavailable(.modelNotReady):
      return "The on-device model isn't ready yet. This is usually because it's still downloading."
    case .unavailable:
      return "An unknown error prevents Apple Intelligence from working."
    }
  }
}

/// Private Cloud Compute is the only provider with adjustable reasoning effort
/// (see https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute) —
/// on-device doesn't support reasoning at all, and Claude/local-server models
/// aren't controlled through `ContextOptions`. `ContextOptions.ReasoningLevel`
/// isn't `Hashable`, so this wraps it in a small `Picker`-friendly type.
enum ReasoningLevelOption: String, CaseIterable, Identifiable {
  case light
  case moderate
  case deep

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light: return "Light"
    case .moderate: return "Moderate"
    case .deep: return "Deep"
    }
  }

  var contextOptionsValue: ContextOptions.ReasoningLevel {
    switch self {
    case .light: return .light
    case .moderate: return .moderate
    case .deep: return .deep
    }
  }
}

extension PrivateCloudComputeLanguageModel {
  /// A human-readable reason Private Cloud Compute can't be used right now,
  /// or `nil` when it's available.
  static var unavailableReasonDescription: String? {
    switch PrivateCloudComputeLanguageModel().availability {
    case .available:
      return nil
    case .unavailable(.deviceNotEligible):
      return "This app or device isn't eligible for Private Cloud Compute. Confirm the com.apple.developer.private-cloud-compute entitlement is added in Signing & Capabilities, and that your account meets Apple's eligibility requirements."
    case .unavailable(.systemNotReady):
      return "Private Cloud Compute isn't ready yet. Try again in a moment."
    @unknown default:
      return "Private Cloud Compute isn't available right now."
    }
  }
}

/// Builds the `LanguageModel` backing a session for the given provider. This is
/// the app's model abstraction layer: everywhere else in the app talks to
/// `LanguageModelSession` the same way, regardless of which provider is active.
///
/// Callers are responsible for checking `provider.unavailableReason` before
/// calling this for `.privateCloudCompute` — this factory trusts that check
/// has already happened and doesn't repeat it.
func makeLanguageModel(for provider: ModelProvider, localServerURLString: String) -> any LanguageModel {
  switch provider {
  case .onDevice:
    return SystemLanguageModel(guardrails: .permissiveContentTransformations)
  case .privateCloudCompute:
    return PrivateCloudComputeLanguageModel()
  case .claude:
    return ClaudeLanguageModel(
      name: .sonnet5,
      auth: .apiKey(ClaudeAPIKeyStore.loadKey() ?? "")
    )
  case .localServer:
    let url = URL(string: localServerURLString) ?? URL(string: ModelProvider.defaultLocalServerURLString)!
    return ChatCompletionsLanguageModel(
      name: "local-model",
      url: url,
      supportsGuidedGeneration: false
    )
  }
}

/// Stores the Anthropic API key in the Keychain rather than in `PromptSettings`,
/// so it survives relaunches without living in a plain in-memory struct.
enum ClaudeAPIKeyStore {
  private static let service = "com.kodeco.FoundationExplorer.claude"
  private static let account = "anthropic-api-key"

  static func loadKey() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func save(key: String) {
    let data = Data(key.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    if loadKey() != nil {
      SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    } else {
      var addQuery = query
      addQuery[kSecValueData as String] = data
      SecItemAdd(addQuery as CFDictionary, nil)
    }
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    SecItemDelete(query as CFDictionary)
  }
}
