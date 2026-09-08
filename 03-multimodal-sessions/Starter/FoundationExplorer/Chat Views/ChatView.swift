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

struct ChatView: View {
  @State private var modelOrchestrator = ModelOrchestrator()
  @State private var promptText = ""
  @State private var messages: [Message] = []
  @FocusState private var isTextFieldFocused: Bool
  @State private var session: LanguageModelSession
  @State private var confirmClear: Bool = false
  @State private var promptSettings: PromptSettings
  @State private var showTranscript = false
  @State private var showSettings = false
  
  init() {
    let settings = PromptSettings(
      instructions: nil,
      temperature: nil,
      sampling: SamplingOptions(type: .system, threshold: 0.33, top: 10),
      reasoning: .none
    )
    _promptSettings = State(initialValue: settings)
    let modelOrchestrator = ModelOrchestrator()
    _modelOrchestrator = State(initialValue: modelOrchestrator)
    _session = State(
      initialValue: LanguageModelSession(
        profile: ChatProfile(modelOrchestrator: modelOrchestrator, settings: settings)
      )
    )
  }
  
  @ToolbarContentBuilder private var appToolbar: some ToolbarContent {
    ToolbarSpacer(.flexible, placement: .bottomBar)
    ToolbarItem(placement: .bottomBar) {
      Button("Show Transcript", systemImage: "sparkles.rectangle.stack") {
        showTranscript = true
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
      .disabled(session.isResponding)
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
      VStack(spacing: 0) {
        Picker("Model", selection: $modelOrchestrator.selectedModel) {
          ForEach(ModelOrchestrator.AvailableModels.allCases, id: \.self) { modelOption in
            Text(modelOption.rawValue).tag(modelOption)
          }
        }
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
          isTextFieldFocused: $isTextFieldFocused,
          sendAction: sendPrompt
        )
        .disabled(session.isResponding)
        Text("Session Usage: \(session.usage.totalTokenCount) tokens.")
          .font(.footnote)
        if modelOrchestrator.selectedModel == .privateCloudCompute {
          QuotaUsageView(model: PrivateCloudComputeLanguageModel())
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
      .sheet(isPresented: $showTranscript) {
        TranscriptView(session: $session)
      }
    }
  }
  
  private func resetChatHistory() {
    messages = []
    
    session = LanguageModelSession(
      profile: ChatProfile(modelOrchestrator: modelOrchestrator, settings: promptSettings)
    )
  }
}

extension ChatView {
  func sendPrompt() async {
    guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    addMessage(promptText, type: .prompt)
    let stream = session.streamResponse(to: promptText)
    promptText = ""
    do {
      for try await partialResponse in stream {
        if messages.last?.type != .partialResponse {
          messages[messages.count - 1].tokens = partialResponse.usage.input.totalTokenCount
          addMessage(
            partialResponse.content,
            type: .partialResponse
          )
        } else {
          messages[messages.count - 1].text = partialResponse.content
        }
        messages[messages.count - 1].tokens = partialResponse.usage.output.totalTokenCount
      }
      let lastIndex = messages.count - 1
      messages[lastIndex].type = .fullResponse
      messages[lastIndex].timestamp = Date.now
    } catch LanguageModelError.contextSizeExceeded(let contextExceeded) {
      let contextExceeded = """
        Context Window contextExceeded: Your session was \(contextExceeded.tokenCount) of \(contextExceeded.contextSize)
      """
      addMessage(contextExceeded, type: .error)
    } catch LanguageModelError.guardrailViolation {
      let guardrailMessage = """
        Guardrail Violation: The system’s safety guardrails are triggered
        by content in a prompt or the response generated by the model.
      """
      addMessage(guardrailMessage, type: .error
      )
    } catch PrivateCloudComputeLanguageModel.Error.quotaLimitReached(let error)  {
      var message = "You have exceeded your available quota."
      if let resetDate = error.resetDate {
        message += " Your quota will reset on \(resetDate.formatted(.dateTime))"
      }
      addMessage(message, type: .error)
    } catch LanguageModelError.unsupportedCapability {
      let message = "You attempted to use capabilities like guided generation or tool calling with a model that does not support them."
      addMessage(message, type: .error)
    } catch {
      addMessage(error.localizedDescription, type: .error)
    }
  }

  private func addMessage(_ message: String, type: MessageType, animate: Bool = true) {
  let newMessage = Message(
      id: UUID(),
      text: message,
      type: type,
      timestamp: Date(),
      tokens: nil
    )
    if animate {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        messages.append(newMessage)
      }
    } else {
      messages.append(newMessage)
    }
  }
}
