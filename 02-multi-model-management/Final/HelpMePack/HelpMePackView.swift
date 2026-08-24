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

struct HelpMePackView: View {
  @State var information = PackingInformation()
  @State var orchestrator = PackingOrchestrator()
  @State var showTranscript = false
  @State var isLoading = false
  @State var session = LanguageModelSession()
  
  var body: some View {
    NavigationStack {
      Form {
        tripSection
        packingSection
      }
      .toolbar {
        appToolbar
      }
      .navigationTitle("Help Me Pack")
    }
  }
  
  @ToolbarContentBuilder private var appToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      NavigationLink {
        TranscriptView(session: $session)
      } label: {
        Image(systemName: "text.page")
      }
    }
  }
  
  @ViewBuilder
  private var tripSection: some View {
    ForEach(Array(information.itinerary.enumerated()), id: \.element.id) { index, _ in
      Section("Destination \(index + 1)") {
        TextField("City", text: $information.itinerary[index].destination)
          .textInputAutocapitalization(.words)
        DatePicker(
          "Start Date",
          selection: $information.itinerary[index].arrivalDate,
          in: arrivalRange(for: index),
          displayedComponents: .date
        )
        .onChange(of: information.itinerary[index].arrivalDate) {
          clampItinerary(startingAt: index)
        }
        DatePicker(
          "End Date",
          selection: $information.itinerary[index].departureDate,
          in: departureRange(for: index),
          displayedComponents: .date
        )
        .onChange(of: information.itinerary[index].departureDate) {
          clampItinerary(startingAt: index + 1)
        }
        if information.itinerary.count > 1 {
          Button("Remove This Destination", role: .destructive) {
            information.itinerary.remove(at: index)
          }
        }
        if information.itinerary[index].destination.isEmpty {
          Text("You must enter a city.")
            .foregroundStyle(.red)
        }
      }
    }

    Section {
      if information.itinerary.count < 3 {
        Button("Add Destination") {
          addDestination()
        }
      }
    }
    Section {
      if isLoading {
        ProgressView("Generating Packing List")
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        Button {
          createNewSession()
          generatePackingList()
        } label: {
          Text("Generate Packing List")
            .disabled(!isItineraryValid || isLoading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .disabled(!isItineraryValid || isLoading || session.isResponding)
      }
    }
  }

  private var packingSection: some View {
    Section("Packing Recommendation") {
      if information.packingRecommendation.isEmpty {
        Text("Your recommendation will appear here.")
          .foregroundStyle(.secondary)
      } else {
        Text(LocalizedStringKey(information.packingRecommendation))
      }
    }
  }

  func createNewSession() {
    orchestrator = PackingOrchestrator()
    session = LanguageModelSession(
      profile: PackingProfile(orchestrator: orchestrator)
    )
  }

  func generatePackingList() {
    let destinations = information.itinerary
      .map {
        "\($0.destination): From \($0.arrivalDate.formatted(date: .numeric, time: .omitted)) to \($0.departureDate.formatted(date: .numeric, time: .omitted))"
      }
      .joined(separator: "\n")

    let weatherPrompt = """
      Built a weather summary for this trip.
      
      Itinerary:
      \(destinations)
      
      1. Retrieve the weather forecast for each destination for the travel dates.
      2. Determine what about the forecast would most impact a visitor of the city only on the dates for that location.
      3. Summarize that information for each location for the indicated dates for the user.
      
      Do not assume weather conditions from general knowledge about any location.
    """
    
    let planningPrompt = """
      Create a weather-aware packing list for this trip.

      Itinerary:
      \(destinations)

      1. A weather summary for each destination has already been established
         earlier in this conversation. Use that summary directly do not
         guess at weather conditions.
      2. Use the summary to decide what clothing and accessories would be
         needed for each destination.
      """
    
    let activityPrompt = """
      Suggest a few things to do for this trip, matched to the best day for
      each based on the weather already established.

      Itinerary:
      \(destinations)

      Use the available tools to find nearby points of interest for each
      destination. Only suggest places the tools actually return. Do not
      look up or guess at weather conditions — use what's already been
      established earlier in this conversation.
      """

    Task {
      isLoading = true
      defer {
        isLoading = false
      }
      // 1
      let weatherFound = await runPrompt(weatherPrompt) { text in
        information.packingRecommendation = text
      }
      // 2
      if !weatherFound {
        return
      }
      // 3
      let weatherText = information.packingRecommendation
      orchestrator.phase = .planning
      // 4
      _ = await runPrompt(planningPrompt) { text in
        information.packingRecommendation = weatherText + "\n\n" + text
      }
      let weatherAndPlanningText = information.packingRecommendation
      orchestrator.phase = .suggestions
      _ = await runPrompt(activityPrompt) { text in
        information.packingRecommendation = weatherAndPlanningText + "\n\n" + text
      }
    }
  }
  
  // 1
  private func runPrompt(
    _ prompt: String,
    onUpdate: @escaping (String) -> Void
  ) async -> Bool {
    // 2
    let stream = session.streamResponse(to: prompt)
    do {
      // 3
      for try await partialResponse in stream {
        onUpdate(partialResponse.content)
      }
    // 4
    } catch let error as LanguageModelSession.ToolCallError {
      onUpdate(toolErrorDescription(for: error))
      return false
    // 5
    } catch {
      onUpdate("Error: \(error.localizedDescription)")
      return false
    }
    // 6
    return true
  }
  
  private func toolErrorDescription(for error: LanguageModelSession.ToolCallError) -> String {
    var errorString = "Error occurred in \(error.tool.name)\n"
    if let underlyingError = error.underlyingError as? WeatherServiceError {
      if case let .serverError(_, message) = underlyingError {
        if message?.contains("Data Unavailable For Requested Point") ?? false {
          errorString += """
          The requested location is not covered by the National Weather Service.

          Please Check Your Location and Try Again.
          """
        } else {
          errorString += underlyingError.errorDescription ?? error.localizedDescription
        }
      } else {
        errorString += underlyingError.errorDescription ?? error.localizedDescription
      }
    }
    return errorString
  }
  
  private var forecastWindow: ClosedRange<Date> {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 7, to: start)!
    return start...end
  }

  private func arrivalRange(for index: Int) -> ClosedRange<Date> {
    let lowerBound = index == 0
      ? forecastWindow.lowerBound
      : information.itinerary[index - 1].departureDate
    return lowerBound...forecastWindow.upperBound
  }

  private func departureRange(for index: Int) -> ClosedRange<Date> {
    information.itinerary[index].arrivalDate...forecastWindow.upperBound
  }

  private func clampItinerary(startingAt index: Int) {
    guard information.itinerary.indices.contains(index) else { return }
    for i in index..<information.itinerary.count {
      let earliestArrival = i == 0
        ? forecastWindow.lowerBound
        : information.itinerary[i - 1].departureDate
      if information.itinerary[i].arrivalDate < earliestArrival {
        information.itinerary[i].arrivalDate = earliestArrival
      }
      if information.itinerary[i].departureDate < information.itinerary[i].arrivalDate {
        information.itinerary[i].departureDate = information.itinerary[i].arrivalDate
      }
      if information.itinerary[i].departureDate > forecastWindow.upperBound {
        information.itinerary[i].departureDate = forecastWindow.upperBound
      }
    }
  }

  private func addDestination() {
    let start = min(information.itinerary.last?.departureDate ?? forecastWindow.lowerBound, forecastWindow.upperBound)
    information.itinerary.append(DestinationInfo(destination: "", arrivalDate: start, departureDate: start))
  }

  private var isItineraryValid: Bool {
    !information.itinerary.isEmpty &&
    information.itinerary.allSatisfy { !$0.destination.isEmpty } &&
    information.itinerary.indices.allSatisfy { i in
      let entry = information.itinerary[i]
      guard entry.arrivalDate <= entry.departureDate else { return false }
      guard i > 0 else { return true }
      return entry.arrivalDate >= information.itinerary[i - 1].departureDate
    }
  }
}

#Preview {
  HelpMePackView()
}
