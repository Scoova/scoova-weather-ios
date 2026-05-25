import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Variables you can request via `current` / `hourly` / `daily`. Subset of
/// scoova weather — extend with `WeatherVar(rawValue: "…")` for anything not listed.
public struct WeatherVar: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    // current / hourly
    public static let temperature2m         = WeatherVar(rawValue: "temperature_2m")
    public static let relativeHumidity2m    = WeatherVar(rawValue: "relative_humidity_2m")
    public static let apparentTemperature   = WeatherVar(rawValue: "apparent_temperature")
    public static let precipitation         = WeatherVar(rawValue: "precipitation")
    public static let rain                  = WeatherVar(rawValue: "rain")
    public static let showers               = WeatherVar(rawValue: "showers")
    public static let snowfall              = WeatherVar(rawValue: "snowfall")
    public static let cloudCover            = WeatherVar(rawValue: "cloud_cover")
    public static let windSpeed10m          = WeatherVar(rawValue: "wind_speed_10m")
    public static let windDirection10m      = WeatherVar(rawValue: "wind_direction_10m")
    public static let windGusts10m          = WeatherVar(rawValue: "wind_gusts_10m")
    public static let weatherCode           = WeatherVar(rawValue: "weather_code")
    public static let pressureMsl           = WeatherVar(rawValue: "pressure_msl")
    public static let visibility            = WeatherVar(rawValue: "visibility")
    public static let uvIndex               = WeatherVar(rawValue: "uv_index")
    public static let isDay                 = WeatherVar(rawValue: "is_day")

    // daily
    public static let temperature2mMax      = WeatherVar(rawValue: "temperature_2m_max")
    public static let temperature2mMin      = WeatherVar(rawValue: "temperature_2m_min")
    public static let precipitationSum      = WeatherVar(rawValue: "precipitation_sum")
    public static let precipitationHours    = WeatherVar(rawValue: "precipitation_hours")
    public static let windSpeed10mMax       = WeatherVar(rawValue: "wind_speed_10m_max")
    public static let sunrise               = WeatherVar(rawValue: "sunrise")
    public static let sunset                = WeatherVar(rawValue: "sunset")
    public static let uvIndexMax            = WeatherVar(rawValue: "uv_index_max")
}

public enum WindSpeedUnit: String, Codable, Sendable { case kmh, ms, mph, kn }
public enum TemperatureUnit: String, Codable, Sendable { case celsius, fahrenheit }
public enum PrecipitationUnit: String, Codable, Sendable { case mm, inch }

public struct ForecastResponse: @unchecked Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public let current: [String: Any]?
    public let hourly: [String: Any]?
    public let daily: [String: Any]?
    public let currentUnits: [String: Any]?
    public let hourlyUnits: [String: Any]?
    public let dailyUnits: [String: Any]?
    public let raw: [String: Any]
}

public enum WeatherError: Error, Sendable {
    case http(Int, String)
    case decode(String)
    case transport(Error)
}

public enum WeatherCondition: String, Sendable {
    case clear, cloudy, fog, drizzle, rain, snow, thunderstorm, unknown
}

/// Map an scoova weather WMO weather code to a coarse-grained condition label.
public func decodeWeatherCode(_ code: Int?) -> WeatherCondition {
    guard let c = code else { return .unknown }
    if c == 0 { return .clear }
    if (1...3).contains(c) { return .cloudy }
    if c == 45 || c == 48 { return .fog }
    if (51...57).contains(c) { return .drizzle }
    if (61...67).contains(c) || (80...82).contains(c) { return .rain }
    if (71...77).contains(c) || c == 85 || c == 86 { return .snow }
    if (95...99).contains(c) { return .thunderstorm }
    return .unknown
}

/// Pluggable HTTP fetcher — used by tests to mock the network without
/// stubbing URLSession. Returns `(statusCode, body)`.
public typealias WeatherHttp = @Sendable (_ url: URL, _ headers: [String: String]) async throws -> (Int, Data)

/// Compatible client for the Scoova weather gateway.
///
/// Defaults to the central Scoova gateway
/// (`https://api.scoo-va.info/api/v1/weather`). Pass `apiKey` for
/// key-enforced calls. The client reads the `SCOOVA_API_KEY`
/// environment variable when `apiKey` is `nil`.
///
/// `locale` accepts BCP-47 codes (`en`, `en-US`, `fr`, `es`, `de`, `it`,
/// `pt-BR`, `nl`, `ar`, `ar-EG`, `ar-SA`, plus regional variants). It is
/// sent as both a `?locale=` query string and `Accept-Language` header.
/// Per-call `locale` overrides the client default.
public actor WeatherClient {
    private let baseUrl: URL
    private let apiKey: String?
    private let defaultLocale: String?
    private let session: URLSession
    private let httpOverride: WeatherHttp?

    public init(
        baseUrl: String = "https://api.scoo-va.info/api/v1/weather",
        apiKey: String? = nil,
        locale: String? = nil,
        session: URLSession = .shared
    ) {
        let trimmed = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseUrl = URL(string: trimmed) ?? URL(string: "http://localhost")!
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["SCOOVA_API_KEY"]
        self.defaultLocale = locale
        self.session = session
        self.httpOverride = nil
    }

    /// Test seam — inject a custom HTTP fetcher.
    public init(
        baseUrl: String,
        apiKey: String? = nil,
        locale: String? = nil,
        http: @escaping WeatherHttp
    ) {
        let trimmed = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseUrl = URL(string: trimmed) ?? URL(string: "http://localhost")!
        self.apiKey = apiKey
        self.defaultLocale = locale
        self.session = .shared
        self.httpOverride = http
    }

    /// Current observed conditions only — minimum payload.
    public func current(
        lat: Double, lon: Double,
        vars: [WeatherVar] = WeatherClient.defaultCurrent,
        locale: String? = nil
    ) async throws -> ForecastResponse {
        try await forecast(lat: lat, lon: lon, current: vars, forecastDays: 1, locale: locale)
    }

    /// Hourly series.
    public func hourly(
        lat: Double, lon: Double,
        vars: [WeatherVar] = WeatherClient.defaultHourly,
        days: Int = 7,
        locale: String? = nil
    ) async throws -> ForecastResponse {
        try await forecast(lat: lat, lon: lon, hourly: vars, forecastDays: days, locale: locale)
    }

    /// Daily summary.
    public func daily(
        lat: Double, lon: Double,
        vars: [WeatherVar] = WeatherClient.defaultDaily,
        days: Int = 7,
        locale: String? = nil
    ) async throws -> ForecastResponse {
        try await forecast(lat: lat, lon: lon, daily: vars, forecastDays: days, locale: locale)
    }

    public func forecast(
        lat: Double, lon: Double,
        current: [WeatherVar]? = nil,
        hourly: [WeatherVar]? = nil,
        daily: [WeatherVar]? = nil,
        timezone: String = "auto",
        forecastDays: Int? = nil,
        pastDays: Int? = nil,
        windSpeedUnit: WindSpeedUnit? = nil,
        temperatureUnit: TemperatureUnit? = nil,
        precipitationUnit: PrecipitationUnit? = nil,
        /// Per-call locale override; overrides the client-level `locale`.
        locale: String? = nil
    ) async throws -> ForecastResponse {
        let effectiveLocale = locale ?? defaultLocale
        var items: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "timezone", value: timezone),
        ]
        if let c = current, !c.isEmpty { items.append(URLQueryItem(name: "current", value: c.map { $0.rawValue }.joined(separator: ","))) }
        if let h = hourly, !h.isEmpty  { items.append(URLQueryItem(name: "hourly",  value: h.map { $0.rawValue }.joined(separator: ","))) }
        if let d = daily, !d.isEmpty   { items.append(URLQueryItem(name: "daily",   value: d.map { $0.rawValue }.joined(separator: ","))) }
        if let f = forecastDays { items.append(URLQueryItem(name: "forecast_days", value: String(f))) }
        if let p = pastDays     { items.append(URLQueryItem(name: "past_days",     value: String(p))) }
        if let u = windSpeedUnit     { items.append(URLQueryItem(name: "wind_speed_unit",   value: u.rawValue)) }
        if let u = temperatureUnit   { items.append(URLQueryItem(name: "temperature_unit", value: u.rawValue)) }
        if let u = precipitationUnit { items.append(URLQueryItem(name: "precipitation_unit", value: u.rawValue)) }
        if let l = effectiveLocale   { items.append(URLQueryItem(name: "locale", value: l)) }

        var components = URLComponents(url: baseUrl.appendingPathComponent("/v1/forecast"), resolvingAgainstBaseURL: false)!
        components.queryItems = items

        let json = try await getJson(components.url!, callLocale: effectiveLocale)
        return Self.toForecast(json)
    }

    /// Escape hatch — hits any path on the weather server, returns parsed JSON.
    public func raw(
        _ path: String,
        params: [String: String] = [:],
        locale: String? = nil
    ) async throws -> [String: Any] {
        let effectiveLocale = locale ?? defaultLocale
        var components = URLComponents(url: baseUrl.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        if let l = effectiveLocale, params["locale"] == nil {
            items.append(URLQueryItem(name: "locale", value: l))
        }
        if !items.isEmpty { components.queryItems = items }
        return try await getJson(components.url!, callLocale: effectiveLocale)
    }

    private func getJson(_ url: URL, callLocale: String?) async throws -> [String: Any] {
        var headers: [String: String] = ["Accept": "application/json"]
        if let apiKey { headers["X-API-Key"] = apiKey }
        if let callLocale { headers["Accept-Language"] = callLocale }

        let data: Data
        if let httpOverride {
            let (status, body): (Int, Data)
            do {
                (status, body) = try await httpOverride(url, headers)
            } catch {
                throw WeatherError.transport(error)
            }
            if !(200..<300).contains(status) {
                let preview = String(data: body, encoding: .utf8)?.prefix(200) ?? ""
                throw WeatherError.http(status, String(preview))
            }
            data = body
        } else {
            var req = URLRequest(url: url)
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            req.timeoutInterval = 30
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: req)
            } catch {
                throw WeatherError.transport(error)
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                throw WeatherError.http(http.statusCode, String(preview))
            }
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw WeatherError.decode("Top-level JSON is not an object")
            }
            return json
        } catch let e as WeatherError {
            throw e
        } catch {
            throw WeatherError.decode(error.localizedDescription)
        }
    }

    nonisolated static func toForecast(_ j: [String: Any]) -> ForecastResponse {
        ForecastResponse(
            latitude: j["latitude"] as? Double ?? 0,
            longitude: j["longitude"] as? Double ?? 0,
            timezone: j["timezone"] as? String ?? "GMT",
            current: j["current"] as? [String: Any],
            hourly: j["hourly"] as? [String: Any],
            daily: j["daily"] as? [String: Any],
            currentUnits: j["current_units"] as? [String: Any],
            hourlyUnits: j["hourly_units"] as? [String: Any],
            dailyUnits: j["daily_units"] as? [String: Any],
            raw: j
        )
    }

    public static let defaultCurrent: [WeatherVar] = [
        .temperature2m, .relativeHumidity2m, .apparentTemperature,
        .precipitation, .windSpeed10m, .windDirection10m, .weatherCode, .isDay,
    ]
    public static let defaultHourly: [WeatherVar] = [
        .temperature2m, .precipitation, .windSpeed10m, .weatherCode,
    ]
    public static let defaultDaily: [WeatherVar] = [
        .temperature2mMax, .temperature2mMin, .precipitationSum,
        .windSpeed10mMax, .weatherCode, .sunrise, .sunset,
    ]
}
