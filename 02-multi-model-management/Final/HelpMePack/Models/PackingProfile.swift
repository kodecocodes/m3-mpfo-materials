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
  
  static let activityInstructions = """
    You are a travel activity assistant that suggests things to do at each
    destination, timed to fit the weather.

    A weather summary for each destination has already been established
    earlier in this conversation. Treat that summary as reliable — do not
    look up or guess at conditions again.

    Use the available tools to find nearby points of interest — such as
    beaches, parks, hiking trails, and nightlife — for each destination.
    If you do not already know a destination's coordinates, use the
    available tools to convert it to latitude and longitude first.

    Only recommend places actually returned by the points of interest
    tool. Do not invent or assume specific venues.

    For each destination:
    - Suggest one or two nearby activities based on the tool results.
    - Recommend which day, or part of the day, of the stay best fits each
      activity, based on the weather summary already established — for
      example, an outdoor or beach activity on a clear, mild day, and an
      indoor or evening option on a day with rain or extreme heat.
    - Briefly explain why that day fits, referencing the forecast.

    Keep suggestions concise and grouped by destination.
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
      // 1
      let pcc = PrivateCloudComputeLanguageModel()
      if pcc.isAvailable && !pcc.quotaUsage.isLimitReached {
        Profile {
          Instructions(PackingProfile.planningInstructions)
        }
        // 2
        .model(pcc)
        .reasoningLevel(.moderate)
      } else {
        // 3
        Profile {
          Instructions(PackingProfile.planningInstructions)
        }
      }
    case .suggestions:
      let pcc = PrivateCloudComputeLanguageModel()
      if pcc.isAvailable && !pcc.quotaUsage.isLimitReached {
        // 1
        Profile {
          Instructions(PackingProfile.activityInstructions)
          GeoLookupTool()
          DestinationHighlightsTool()
        }
        // 2
        .model(pcc)
        .reasoningLevel(.moderate)
        // 3
        .historyTransform { history in
          // 4
          history.filter {
            switch $0 {
            case .prompt:
              return true
            case .response:
              return true
            default:
              return false
            }
          }
        }
      } else {
        // 5
        Profile {
          Instructions(PackingProfile.activityInstructions)
          GeoLookupTool()
          DestinationHighlightsTool()
        }
        .historyTransform { history in
          // 6
          history.filter {
            switch $0 {
            case .prompt:
              return true
            case .response:
              return true
            default:
              return false
            }
          }
          .dropLast(2)
        }
      }
    }
  }
}
