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

struct WeatherSummary: Sendable {
  let locationName: String
  let periods: [WeatherPeriod]
}

struct WeatherPeriod: Sendable {
  let name: String
  let startTime: Date
  let endTime: Date
  let temperature: Int
  let temperatureUnit: String
  let shortForecast: String
  let detailedForecast: String
  let windSpeed: String
}

enum WeatherServiceError: Error {
  case invalidCoordinates(latitude: Double, longitude: Double)
  case invalidURL(String)
  case invalidHTTPResponse
  case serverError(statusCode: Int, message: String?)
  case decodingFailed(Error)
  case requestFailed(Error)

  var errorDescription: String? {
    switch self {
    case let .invalidCoordinates(latitude, longitude):
      return "Invalid coordinates: latitude \(latitude), longitude \(longitude)."

    case let .invalidURL(urlString):
      return "Could not create a valid URL from: \(urlString)"

    case .invalidHTTPResponse:
      return "The weather service returned an invalid response."

    case let .serverError(statusCode, message):
      if let message, !message.isEmpty {
        return "The weather service returned status code \(statusCode): \(message)"
      } else {
        return "The weather service returned status code \(statusCode)."
      }

    case let .decodingFailed(error):
      return "Could not read the weather service response: \(error.localizedDescription)"

    case let .requestFailed(error):
      return "Could not contact the weather service: \(error.localizedDescription)"
    }
  }
}

struct NWSPointResponse: Decodable {
  let properties: Properties

  struct Properties: Decodable {
    let forecast: URL
    let relativeLocation: RelativeLocation
  }

  struct RelativeLocation: Decodable {
    let properties: LocationProperties
  }

  struct LocationProperties: Decodable {
    let city: String
    let state: String
  }
}

struct NWSForecastResponse: Decodable {
  let properties: Properties

  struct Properties: Decodable {
    let periods: [Period]
  }

  struct Period: Decodable {
    let name: String
    let startTime: Date
    let endTime: Date
    let temperature: Int
    let temperatureUnit: String
    let windSpeed: String
    let shortForecast: String
    let detailedForecast: String
  }
}

struct NWSWeatherService {
  private let session: URLSession
  private let decoder: JSONDecoder
  private let userAgent: String

  init(
    session: URLSession = .shared,
    //  Change Below to Your Email
    userAgent: String = "HelpMePack/1.0 email@example.com"
  ) {
    self.session = session
    self.userAgent = userAgent

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  func forecast(latitude: Double, longitude: Double) async throws -> WeatherSummary {
    guard (-90...90).contains(latitude),
          (-180...180).contains(longitude) else {
      throw WeatherServiceError.invalidCoordinates(
        latitude: latitude,
        longitude: longitude
      )
    }

    let point = try await fetchPointMetadata(
      latitude: latitude,
      longitude: longitude
    )

    let forecastResponse = try await fetchForecast(
      from: point.properties.forecast
    )

    return WeatherSummary(
      locationName: "\(point.properties.relativeLocation.properties.city), \(point.properties.relativeLocation.properties.state)",
      periods: forecastResponse.properties.periods.map { period in
        WeatherPeriod(
          name: period.name,
          startTime: period.startTime,
          endTime: period.endTime,
          temperature: period.temperature,
          temperatureUnit: period.temperatureUnit,
          shortForecast: period.shortForecast,
          detailedForecast: period.detailedForecast,
          windSpeed: period.windSpeed
        )
      }
    )
  }

  private func fetchPointMetadata(
    latitude: Double,
    longitude: Double
  ) async throws -> NWSPointResponse {
    let urlString = "https://api.weather.gov/points/\(latitude),\(longitude)"

    guard let url = URL(string: urlString) else {
      throw WeatherServiceError.invalidURL(urlString)
    }

    return try await get(url)
  }

  private func fetchForecast(from url: URL) async throws -> NWSForecastResponse {
    try await get(url)
  }

  private func get<T: Decodable>(_ url: URL) async throws -> T {
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/geo+json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw WeatherServiceError.requestFailed(error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw WeatherServiceError.invalidHTTPResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let message = String(data: data, encoding: .utf8)
      throw WeatherServiceError.serverError(
        statusCode: httpResponse.statusCode,
        message: message
      )
    }

    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw WeatherServiceError.decodingFailed(error)
    }
  }
}
