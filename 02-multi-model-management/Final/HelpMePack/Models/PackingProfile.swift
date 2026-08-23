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

struct PackingProfile: LanguageModelSession.DynamicProfile {
  var orchestrator: PackingOrchestrator
  
  static let weatherInstructions = """
    You are a packing assistant that creates practical packing lists for travelers.

    First determine the trip destinations and dates. The trip may include
    multiple locations. Use tools to get the forecast for each destination
    on its travel dates.

    Use the available tools to gather weather information for the trip.
    Also use available tools to convert locations and city names into
    latitude and longitude.
    Do not guess weather conditions, temperatures, or precipitation.

    For each destination, summarize the expected conditions across the travel dates
    for that location, noting anything the traveler should be aware of, such as high
    heat, a cold snap, or high chance of precipitation.

    Do not provide any suggestions on packing for this step, just information on
    the weather.
    """

  static let planningInstructions = """
    You are a travel planning assistant that builds a packing list from
    a weather summary already gathered earlier in this conversation.

    Treat that summary as reliable, established information. Do not attempt
    to look up or reverify the forecast. Producing the list is now your job.

    Recommend only items that are useful for the trip conditions.
    Keep the list concise, realistic, and grouped by category.
    Explain briefly why weather-specific items are included.
    """
  
  var body: some LanguageModelSession.DynamicProfile {
    switch orchestrator.phase {
      // 1
      case .weather:
      Profile {
        Instructions(PackingProfile.weatherInstructions)
        GeoLookupTool()
        WeatherForecastTool()
      }
    case .planning:
      // 2
      Profile {
        Instructions(PackingProfile.planningInstructions)
      }
    }
  }
}
