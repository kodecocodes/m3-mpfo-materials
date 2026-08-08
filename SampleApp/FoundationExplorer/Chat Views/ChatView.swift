/// Copyright (c) 2025 Kodeco Inc.
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
import _FoundationModels_UIKit

struct ChatView: View {
  @State private var promptText = ""
  @State private var selectedImageData: Data?
  @State private var messages: [Message] = []
  @FocusState private var isTextFieldFocused: Bool
  @State private var session = LanguageModelSession(
    model: SystemLanguageModel(
      guardrails: .permissiveContentTransformations
    )
  )
  @State private var confirmClear: Bool = false
  @State private var contextWindowSize: Int?
  /// Set from the active model's own `capabilities` whenever the session is
  /// rebuilt — not a guess about which providers support what. Passing
  /// `reasoningLevel` to a model whose `capabilities` don't include
  /// `.reasoning` throws `LanguageModelError.unsupportedCapability`. Only
  /// used by the plain-provider path in `sendPrompt()`; the Dynamic Profile
  /// path applies `.reasoningLevel(_:)` itself, in `ChatDynamicProfile`.
  @State private var modelSupportsReasoning = false
  @State private var promptSettings =
  PromptSettings(
    instructions: nil,
    temperature: nil,
    sampling: SamplingOptions(type: .system, threshold: 0.33, top: 10)
  )
  @State private var showSettings = false
  @State private var isCompactingContext = false
  @State private var lastUsage: LanguageModelSession.Usage?
  @State private var chatState = ChatState()

  @ToolbarContentBuilder private var appToolbar: some ToolbarContent {
    ToolbarSpacer(.flexible, placement: .bottomBar)
    ToolbarItem(placement: .bottomBar) {
      Button("Compact", systemImage: "sparkles.rectangle.stack") {
        Task {
          await summarizeChat()
        }
      }
    }
    ToolbarItem(placement: .bottomBar) {
      Button("Settings", systemImage: "gear") {
        showSettings = true
      }
    }
    ToolbarItem(placement: .bottomBar) {
      Button("Clear", systemImage: "xmark.circle.fill") {
        confirmClear = true
      }
      .tint(.red)
      .confirmationDialog(
        "Are you sure you want to delete the chat history?",
        isPresented: $confirmClear
      ) {
        Button("Delete Chat History", role: .destructive) {
          resetChatHistory()
        }
      }
    }
  }

  var body: some View {
    NavigationView {
      Group {
        if let onDeviceUnavailableReason {
          ModelUnavailableView(reason: onDeviceUnavailableReason)
        } else {
      VStack(spacing: 0) {
        // Instructions
        if messages.isEmpty {
          Text("Welcome to Foundation Explorer. Enter a message to begin interacting with the Foundation Model.")
            .font(.title2)
        }
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(messages) { message in
                MessageBubble(message: message)
                  .id(message.id)
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            if session.isResponding {
              TypingIndicator()
                .transition(.scale)
            }
          }
          .onChange(of: messages.count) { _, _ in
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(messages.last?.id, anchor: .bottom)
            }
          }
          .onChange(of: messages.last?.text) { _, _ in
            withAnimation(.easeInOut(duration: 0.1)) {
              proxy.scrollTo(messages.last?.id, anchor: .bottom)
            }
          }
        }
        MessageInputView(
          messageText: $promptText,
          selectedImageData: $selectedImageData,
          isTextFieldFocused: $isTextFieldFocused,
          sendAction: sendPrompt
        )
        .disabled(session.isResponding)
        switch effectiveProvider {
        case .onDevice:
          if let tokenCount = contextWindowSize {
            Text("Context Window: \(tokenCount)/\(SystemLanguageModel.default.contextSize) tokens.")
              .font(.footnote)
          } else {
            Text("Context Window: \(SystemLanguageModel.default.contextSize) tokens.")
              .font(.footnote)
          }
        case .privateCloudCompute:
          PrivateCloudComputeQuotaView()
            .font(.footnote)
        case .claude, .localServer:
          EmptyView()
        }
        if let usage = lastUsage {
          Text("Usage: \(usage.input.totalTokenCount) in (\(usage.input.cachedTokenCount) cached) / \(usage.output.totalTokenCount) out")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        if promptSettings.useDynamicProfile {
          Text("Mode: \(chatState.mode.title)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          if !chatState.skillActivations.activeSkillNames.isEmpty {
            Text("Active Skills: \(chatState.skillActivations.activeSkillNames.joined(separator: ", "))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
        }
      }
      .overlay {
        if isCompactingContext {
          VStack(alignment: .center) {
            CompactionIndicatorView()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.ultraThinMaterial)
        }
      }
      .navigationTitle("Foundation Explorer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        appToolbar
      }
      .sheet(isPresented: $showSettings) {
        ConfigurationView(settings: $promptSettings)
      }
      .onChange(of: promptSettings.instructions) {
        Task {
          resetChatHistory()
          await updatedContextWindowUsed()
        }
      }
      .onChange(of: promptSettings.modelProvider) {
        Task {
          resetChatHistory()
          await updatedContextWindowUsed()
        }
      }
      .onChange(of: promptSettings.useDynamicProfile) {
        Task {
          resetChatHistory()
          await updatedContextWindowUsed()
        }
      }
      .onChange(of: promptSettings.useFrameworkHistoryManagement) {
        Task {
          resetChatHistory()
          await updatedContextWindowUsed()
        }
      }
    }
  }

  /// `nil` unless the on-device model is the one actually in use *and* it's
  /// unavailable. Checked live from `body` rather than once at app launch,
  /// since the user can switch providers, or DynamicProfile can be toggled.
  /// A Dynamic Profile always starts in `.quickReply` (on-device), so
  /// on-device availability matters whenever it's enabled, regardless of
  /// `promptSettings.modelProvider`.
  private var onDeviceUnavailableReason: SystemLanguageModel.Availability.UnavailableReason? {
    let usesOnDeviceModel = promptSettings.useDynamicProfile || promptSettings.modelProvider == .onDevice
    guard usesOnDeviceModel else { return nil }
    guard case .unavailable(let reason) = SystemLanguageModel.default.availability else { return nil }
    return reason
  }

  /// The provider actually backing the session right now. When a Dynamic
  /// Profile is active, `promptSettings.modelProvider` is beside the point —
  /// the profile always starts on-device (`.quickReply`) and can switch to
  /// Private Cloud Compute (`.deepReasoning`) via `SwitchModeTool`. Context
  /// window/quota display and token counting need to track *this*, not the
  /// provider picker, or they'd show the wrong model's info whenever the
  /// profile has escalated.
  private var effectiveProvider: ModelProvider {
    if promptSettings.useDynamicProfile {
      return chatState.mode == .deepReasoning ? .privateCloudCompute : .onDevice
    }
    return promptSettings.modelProvider
  }

  private func resetChatHistory() {
    messages = []
    lastUsage = nil
    selectedImageData = nil
    chatState.mode = .quickReply
    session = promptSettings.useDynamicProfile
      ? makeDynamicProfileSession()
      : makeSession(for: promptSettings.modelProvider)
    Task {
      await updatedContextWindowUsed()
    }
  }

  /// Builds a session for the given provider. Every `ModelProvider` resolves to
  /// a type conforming to `LanguageModel` (see `makeLanguageModel(for:localServerURLString:)`
  /// in ModelProvider.swift), so this is the only place that needs to branch on
  /// which provider is active — everything downstream (streaming, sampling
  /// options, error handling) is unchanged regardless of the model backing it.
  private func makeSession(for provider: ModelProvider) -> LanguageModelSession {
    var resolvedProvider = provider
    if let reason = provider.unavailableReason {
      addMessage(
        "Private Cloud Compute is unavailable, falling back to on-device: \(reason)",
        type: .error
      )
      resolvedProvider = .onDevice
    }
    let model = makeLanguageModel(
      for: resolvedProvider,
      localServerURLString: promptSettings.localServerURLString
    )
    modelSupportsReasoning = model.capabilities.contains(.reasoning)
    if let instructions = promptSettings.instructions {
      return LanguageModelSession(model: model, instructions: instructions)
    }
    return LanguageModelSession(model: model)
  }

  /// Builds a session from `ChatDynamicProfile` instead of a single fixed
  /// model. The profile itself picks the model per turn based on `chatState.mode`,
  /// which `SwitchModeTool` can change mid-conversation.
  private func makeDynamicProfileSession() -> LanguageModelSession {
    LanguageModelSession(
      profile: ChatDynamicProfile(
        state: chatState,
        instructions: promptSettings.instructions,
        useFrameworkHistoryManagement: promptSettings.useFrameworkHistoryManagement,
        reasoningLevel: promptSettings.reasoningLevel.contextOptionsValue
      )
    )
  }

  /// Only `SystemLanguageModel` exposes `tokenCount(for:)` — Private Cloud
  /// Compute reports usage through a daily quota instead (see
  /// `PrivateCloudComputeQuotaView`), and Claude/local-server models have no
  /// equivalent API at all. Counting tokens with the on-device tokenizer
  /// while a different provider is active would just be wrong, so both of
  /// the methods below are no-ops unless on-device is actually the model in
  /// use (see `effectiveProvider`).
  private func updatedContextWindowUsed() async {
    guard effectiveProvider == .onDevice else {
      contextWindowSize = nil
      return
    }
    guard #available(iOS 26.4, *) else {
      contextWindowSize = nil
      return
    }
    contextWindowSize = try? await SystemLanguageModel.default.tokenCount(for: session.transcript)
  }

  private func tokenCount(for text: String) async -> Int? {
    guard effectiveProvider == .onDevice else { return nil }
    guard #available(iOS 26.4, *) else { return nil }
    return try? await SystemLanguageModel.default.tokenCount(for: Prompt(text))
  }

  @MainActor
  private func summarizeChat() async {
    isCompactingContext = true
    defer {
      isCompactingContext = false
    }
    
    let entriesToKeep = Array(
      session.transcript
        .filter {
          if case .response = $0 {
            return true
          }
          return false
        }
    )
    
    let textToSummarize = entriesToKeep.map {
      $0.description
    }
      .joined(separator: "\n")
    
    let summaryInstructions = """
      You are given a conversation transcript.
      
      Your job is to extract and compress it into memory.
      
      You are NOT an assistant responding to the conversation.
      
      You MUST NOT answer any user requests.
      
      STEP 1: Identify all user requests in the transcript.
      STEP 2: For each request, extract a short summary of the assistant's response.
      
      Do not skip any requests. Include earlier and later ones.
      """
    
    let summarySession = LanguageModelSession(instructions: summaryInstructions)
    let summarizedText = try? await summarySession.respond(to: textToSummarize)
    
    // 1
    messages = []
    
    // 2
    if let summary = summarizedText?.content {
      // 3
      useSummary(summary)
    } else {
      // 4
      trimSession(entriesToKeep)
    }
    // 5
    await updatedContextWindowUsed()
  }

  func useSummary(_ summary: String) {
    // 1
    var entries: [Transcript.Entry] = []

    // 2
    if let instructions = promptSettings.instructions {
      entries.append(
        // 3
        .instructions(
          .init(
            // 4
            segments: [
              // 5
              .text(
                .init(content: instructions)
              )
            ],
            // 6
            toolDefinitions: []
          )
        )
      )
    }

    entries.append(
      .prompt(
        .init(
          segments: [
            .text(
              .init(content: summary)
            )
          ]
        )
      )
    )

    let newTranscript = Transcript(entries: entries)
    session = LanguageModelSession(transcript: newTranscript)
    addMessage(summary, type: .summary)
  }

  func trimSession(_ entries: [Transcript.Entry]) {
    // 1
    var summaryEntries: [Transcript.Entry] = []

    if let instruction = promptSettings.instructions {
      summaryEntries.append(
        .instructions(
          .init(
            segments: [
              .text(
                .init(content: instruction)
              )
            ],
            toolDefinitions: []
          )
        )
      )
    }

    // 2
    let lastEntries = Array(entries.dropFirst(entries.count / 3))
    // 3
    summaryEntries.append(contentsOf: lastEntries)
    // 4
    let newTranscript = Transcript(entries: summaryEntries)
    // 5
    session = LanguageModelSession(transcript: newTranscript)
    for entry in lastEntries {
      addMessage(entry.description, type: .summary)
    }
  }
}

extension ChatView {
  func sendPrompt() async {
    guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil else {
      return
    }

    addMessage(promptText, type: .prompt, imageData: selectedImageData)
    let samplingOptions = promptSettings.sampling
    var sampling: GenerationOptions.SamplingMode?
    switch samplingOptions.type {
    case .system:
      sampling = nil
    case .greedy:
      sampling = GenerationOptions.SamplingMode.greedy
    case .top:
      sampling = GenerationOptions.SamplingMode.random(
        top: samplingOptions.top,
        seed: samplingOptions.seed
      )
    case .threshold:
      sampling = GenerationOptions.SamplingMode.random(
        probabilityThreshold: samplingOptions.threshold,
        seed: samplingOptions.seed
      )
    }
    let options = GenerationOptions(
      samplingMode: sampling,
      temperature: promptSettings.temperature
    )
    // ChatDynamicProfile already applies reasoningLevel via .reasoningLevel(_:)
    // on its Private Cloud Compute branch — passing contextOptions here too
    // would just be a second, redundant way of saying the same thing.
    // Otherwise, passing reasoningLevel to a model whose capabilities don't
    // include .reasoning throws LanguageModelError.unsupportedCapability —
    // checked against the active model's real capabilities (see
    // modelSupportsReasoning), not assumed from which provider is selected.
    let contextOptions = (!promptSettings.useDynamicProfile && modelSupportsReasoning)
      ? ContextOptions(reasoningLevel: promptSettings.reasoningLevel.contextOptionsValue)
      : ContextOptions()
    let stream: LanguageModelSession.ResponseStream<String>
    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
      stream = session.streamResponse(options: options, contextOptions: contextOptions) {
        if !promptText.isEmpty {
          promptText
        }
        Attachment(uiImage)
      }
    } else {
      stream = session.streamResponse(to: promptText, options: options, contextOptions: contextOptions)
    }
    promptText = ""
    selectedImageData = nil
    do {
      for try await partialResponse in stream {
        if messages.last?.type != .partialResponse {
          addMessage(
            partialResponse.content,
            type: .partialResponse
          )
        } else {
          messages[messages.count - 1].text = partialResponse.content
        }
        lastUsage = partialResponse.usage
      }
      let lastIndex = messages.count - 1
      messages[lastIndex].type = .fullResponse
      messages[lastIndex].timestamp = Date.now
      messages[lastIndex].tokens = await tokenCount(for: messages[lastIndex].text)
    } catch LanguageModelError.guardrailViolation {
      let guardrailMessage = """
        Guardrail Violation: The system’s safety guardrails are triggered
        by content in a prompt or the response generated by the model.
      """
      addMessage(guardrailMessage, type: .error
      )
    } catch LanguageModelError.contextSizeExceeded {
      await summarizeChat()
    } catch LanguageModelError.rateLimited(let info) {
      // Private Cloud Compute throws this when a person exhausts their daily
      // quota — see PrivateCloudComputeQuotaView and Apple's guide at
      // https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
      if let resetDate = info.resetDate {
        addMessage(
          "Usage limit reached. Try again after \(resetDate.formatted(date: .abbreviated, time: .shortened)), or upgrade in Settings.",
          type: .error
        )
      } else {
        addMessage("Usage limit reached. Try again later, or upgrade in Settings.", type: .error)
      }
    } catch {
      addMessage(error.localizedDescription, type: .error)
    }
    await updatedContextWindowUsed()
  }

  private func addMessage(_ message: String, type: MessageType, animate: Bool = true, imageData: Data? = nil) {
    let newMessage = Message(
      id: UUID(),
      text: message,
      type: type,
      timestamp: Date(),
      tokens: nil,
      imageData: imageData
    )
    if animate {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        messages.append(newMessage)
      }
    } else {
      messages.append(newMessage)
    }

    guard type == .prompt || type == .fullResponse else { return }
    Task {
      let tokens = await tokenCount(for: message)
      if let index = messages.firstIndex(where: { $0.id == newMessage.id }) {
        messages[index].tokens = tokens
      }
    }
  }
}
