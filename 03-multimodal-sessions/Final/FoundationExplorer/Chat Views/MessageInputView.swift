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
import PhotosUI

struct MessageInputView: View {
  @Binding var messageText: String
  @Binding var image: UIImage?
  @State var tokenCount: Int?
  @FocusState.Binding var isTextFieldFocused: Bool
  let sendAction: () async -> Void
  @State private var pickerItem: PhotosPickerItem?

  var body: some View {
    VStack(spacing: 0) {
      Divider()

      HStack(spacing: 12) {
        PhotosPicker(selection: $pickerItem, matching: .images) {
          Image(systemName: "photo.badge.plus")
            .font(.title2)
            .foregroundColor(image == nil ? .gray : .blue)
        }
        HStack(spacing: 8) {
          TextField("Message", text: $messageText, axis: .vertical)
            .focused($isTextFieldFocused)
            .lineLimit(1...4)
            .onSubmit {
              Task {
                tokenCount = nil
                await sendAction()
              }
            }

          if !messageText.isEmpty {
            Button {
              Task {
                tokenCount = nil
                await sendAction()
              }
            } label: {
              Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            }
            .transition(.scale.combined(with: .opacity))
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemGray6))
        )
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .background(Color(.systemBackground))
      if let tokenCount = tokenCount {
        HStack {
          Spacer()
          Text(tokenCount, format: .number)
            .padding(.trailing, 2)
          Text(" tokens")
        }
        .padding(.trailing)
        .font(.footnote)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
    .onChange(of: pickerItem) {
      Task {
        guard let pickerItem,
              let data = try? await pickerItem.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
          return
        }
        image = uiImage
      }
    }
    if let image {
      HStack {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 60, height: 60)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(alignment: .topTrailing) {
            Button {
              self.image = nil
              pickerItem = nil
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
          }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .transition(.scale.combined(with: .opacity))
    }
  }
  
  func clearInput() {
    messageText = ""
    image = nil
  }
}

// Preview
#Preview("With Text") {
  @Previewable @State var messageText = "Books are fun."
  @Previewable @FocusState var isTextFieldFocused: Bool
  @Previewable @State var image: UIImage?

  MessageInputView(
    messageText: $messageText,
    image: $image,
    isTextFieldFocused: $isTextFieldFocused
  ) {
    print("Message \(messageText) sent.")
  }
}

#Preview("No Text") {
  @Previewable @State var messageText = ""
  @Previewable @FocusState var isTextFieldFocused: Bool
  @Previewable @State var image: UIImage?

  MessageInputView(
    messageText: $messageText,
    image: $image,
    isTextFieldFocused: $isTextFieldFocused
  ) {
    print("Message \(messageText) sent.")
  }
}
