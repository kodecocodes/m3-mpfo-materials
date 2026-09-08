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
import Vision

struct ImageAestheticsTool: Tool {
  @SessionProperty(\.history) var history

  let name = "calculateImageAesthetics"
  let description = """
  Calculates an image's aesthetic appeal score and determines whether it is a
  utility image. Use only for requests about aesthetics, visual appeal, or image quality.
  """

  @Generable
  struct Arguments {
    @Guide(description: "The identifier of the image to analyze.")
    var image: ImageReference
  }
  
  func call(arguments: Arguments) async throws -> String {
    guard let attachment = arguments.image.resolved(in: history) else {
      return "The image isn't in the session history."
    }
    
    let aestheticsScoresRequest = CalculateImageAestheticsScoresRequest()
    let aesthetics = try await aestheticsScoresRequest.perform(
      on: attachment.cgImage,
      orientation: attachment.orientation
    )
    return "The image has an aesthetic score of \(aesthetics.overallScore) and \(aesthetics.isUtility ? "is" : "is not") a utility image."
  }
}
