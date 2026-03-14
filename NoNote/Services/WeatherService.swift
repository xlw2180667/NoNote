import Foundation
import CoreLocation
import SwiftUI

// MARK: - Weather Condition

enum WeatherCondition: String, CaseIterable {
    case clear
    case partlyCloudy
    case foggy
    case drizzle
    case rain
    case freezingRain
    case snow
    case showers
    case snowShowers
    case thunderstorm

    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .foggy:        return "cloud.fog.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .freezingRain: return "cloud.sleet.fill"
        case .snow:         return "cloud.snow.fill"
        case .showers:      return "cloud.heavyrain.fill"
        case .snowShowers:  return "snowflake"
        case .thunderstorm: return "cloud.bolt.fill"
        }
    }

    var labelKey: String {
        switch self {
        case .clear:        return "#weatherClear"
        case .partlyCloudy: return "#weatherPartlyCloudy"
        case .foggy:        return "#weatherFoggy"
        case .drizzle:      return "#weatherDrizzle"
        case .rain:         return "#weatherRain"
        case .freezingRain: return "#weatherFreezingRain"
        case .snow:         return "#weatherSnow"
        case .showers:      return "#weatherShowers"
        case .snowShowers:  return "#weatherSnowShowers"
        case .thunderstorm: return "#weatherThunderstorm"
        }
    }

    var color: Color {
        switch self {
        case .clear:        return .orange
        case .partlyCloudy: return .yellow
        case .foggy:        return .gray
        case .drizzle:      return .cyan
        case .rain:         return .blue
        case .freezingRain: return .blue.opacity(0.7)
        case .snow:         return .mint
        case .showers:      return .indigo
        case .snowShowers:  return .cyan
        case .thunderstorm: return .purple
        }
    }

    /// The representative WMO code stored for this condition.
    var wmoCode: String {
        switch self {
        case .clear:        return "0"
        case .partlyCloudy: return "2"
        case .foggy:        return "45"
        case .drizzle:      return "53"
        case .rain:         return "63"
        case .freezingRain: return "66"
        case .snow:         return "73"
        case .showers:      return "81"
        case .snowShowers:  return "85"
        case .thunderstorm: return "95"
        }
    }

    static func from(wmoCode: Int) -> WeatherCondition {
        switch wmoCode {
        case 0:             return .clear
        case 1, 2, 3:       return .partlyCloudy
        case 45, 48:        return .foggy
        case 51, 53, 55:    return .drizzle
        case 61, 63, 65:    return .rain
        case 66, 67:        return .freezingRain
        case 71, 73, 75, 77: return .snow
        case 80, 81, 82:    return .showers
        case 85, 86:        return .snowShowers
        case 95, 96, 99:    return .thunderstorm
        default:            return .partlyCloudy
        }
    }

    static func from(code: String) -> WeatherCondition? {
        guard let intCode = Int(code) else { return nil }
        return from(wmoCode: intCode)
    }

    static func symbolForCode(_ code: String) -> String {
        from(code: code)?.sfSymbol ?? "cloud.fill"
    }

    static func colorForCode(_ code: String) -> Color {
        from(code: code)?.color ?? .gray
    }
}

// MARK: - Weather Service

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    /// The latest fetched weather code. Editor reads this synchronously.
    @Published var currentWeatherCode: String?

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var isFetching = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Call on app launch and when returning from background.
    func refresh() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            defer { isFetching = false }
            do {
                let code = try await fetchWeather()
                currentWeatherCode = code
            } catch {
                print("WeatherService: refresh failed — \(error)")
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // After user grants permission, start location request
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if locationContinuation != nil {
                manager.requestLocation()
            }
        } else if status == .denied || status == .restricted {
            locationContinuation?.resume(throwing: URLError(.userAuthenticationRequired))
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    // MARK: - Private

    private func fetchWeather() async throws -> String {
        let location = try await requestLocation()
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let currentWeather = json?["current_weather"] as? [String: Any],
              let weatherCode = currentWeather["weathercode"] as? Int else {
            throw URLError(.cannotParseResponse)
        }

        return String(weatherCode)
    }

    private func requestLocation() async throws -> CLLocation {
        // Use cached location if fresh enough (< 10 minutes)
        if let lastLocation = locationManager.location,
           abs(lastLocation.timestamp.timeIntervalSinceNow) < 600 {
            return lastLocation
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation

            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                // Delegate callback will fire requestLocation() after user grants
                locationManager.requestWhenInUseAuthorization()
            } else if status == .denied || status == .restricted {
                locationContinuation = nil
                continuation.resume(throwing: URLError(.userAuthenticationRequired))
            } else {
                locationManager.requestLocation()
            }
        }
    }
}
