import XCTest
@testable import ScoovaWeather

final class WeatherCodeTests: XCTestCase {
    func testWmoMapping() {
        XCTAssertEqual(decodeWeatherCode(0), .clear)
        XCTAssertEqual(decodeWeatherCode(2), .cloudy)
        XCTAssertEqual(decodeWeatherCode(45), .fog)
        XCTAssertEqual(decodeWeatherCode(53), .drizzle)
        XCTAssertEqual(decodeWeatherCode(63), .rain)
        XCTAssertEqual(decodeWeatherCode(80), .rain)
        XCTAssertEqual(decodeWeatherCode(73), .snow)
        XCTAssertEqual(decodeWeatherCode(96), .thunderstorm)
        XCTAssertEqual(decodeWeatherCode(nil), .unknown)
        XCTAssertEqual(decodeWeatherCode(999), .unknown)
    }
}

final class ForecastResponseTests: XCTestCase {
    func testToForecastParsesAllBlocks() {
        let raw: [String: Any] = [
            "latitude": 30.0625,
            "longitude": 31.25,
            "generationtime_ms": 0.1,
            "utc_offset_seconds": 7200,
            "timezone": "Africa/Cairo",
            "timezone_abbreviation": "EET",
            "current_units": ["temperature_2m": "°C"],
            "current": ["time": "2026-05-04T17:00", "interval": 900, "temperature_2m": 24.1] as [String: Any],
            "hourly_units": ["temperature_2m": "°C"],
            "hourly": [
                "time": ["2026-05-04T00:00", "2026-05-04T01:00"],
                "temperature_2m": [16.1, 15.9],
            ] as [String: Any],
        ]
        let r = WeatherClient.toForecast(raw)
        XCTAssertEqual(r.latitude, 30.0625, accuracy: 0.0001)
        XCTAssertEqual(r.longitude, 31.25, accuracy: 0.0001)
        XCTAssertEqual(r.timezone, "Africa/Cairo")
        XCTAssertEqual(r.current?["temperature_2m"] as? Double, 24.1)
        XCTAssertEqual(r.hourly?["time"] as? [String], ["2026-05-04T00:00", "2026-05-04T01:00"])
        XCTAssertNil(r.daily)
    }
}

final class WeatherVarTests: XCTestCase {
    func testDefaultsUseOpenMeteoNames() {
        XCTAssertTrue(WeatherClient.defaultCurrent.contains(.temperature2m))
        XCTAssertEqual(WeatherVar.precipitationSum.rawValue, "precipitation_sum")
        XCTAssertEqual(WeatherVar.weatherCode.rawValue, "weather_code")
    }
}

final class WeatherClientTests: XCTestCase {
    func testBuildsForecastUrlAndForwardsLocaleAndKey() async throws {
        actor Capture {
            var url: URL?
            var headers: [String: String] = [:]
            func set(_ u: URL, _ h: [String: String]) { self.url = u; self.headers = h }
            func read() -> (URL?, [String: String]) { (url, headers) }
        }
        let capture = Capture()

        let body = """
        {"latitude":30.0625,"longitude":31.25,"timezone":"Africa/Cairo",
         "current":{"time":"2026-05-04T17:00","interval":900,"temperature_2m":24.1}}
        """.data(using: .utf8)!

        let client = WeatherClient(
            baseUrl: "https://api.scoo-va.info/v1/weather",
            apiKey: "sk_live_abc",
            locale: "fr",
            http: { url, headers in
                await capture.set(url, headers)
                return (200, body)
            }
        )

        _ = try await client.current(lat: 30.04, lon: 31.24)

        let (u, h) = await capture.read()
        XCTAssertEqual(u?.path, "/v1/weather/v1/forecast")
        XCTAssertEqual(h["X-API-Key"], "sk_live_abc")
        XCTAssertEqual(h["Accept-Language"], "fr")

        let qs = (u.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? [])
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        XCTAssertEqual(qs["latitude"], "30.04")
        XCTAssertEqual(qs["longitude"], "31.24")
        XCTAssertEqual(qs["timezone"], "auto")
        XCTAssertEqual(qs["locale"], "fr")
        XCTAssertEqual(qs["current"], "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,wind_speed_10m,wind_direction_10m,weather_code,is_day")
    }

    func testPerCallLocaleOverridesDefault() async throws {
        actor Capture {
            var url: URL?
            var headers: [String: String] = [:]
            func set(_ u: URL, _ h: [String: String]) { self.url = u; self.headers = h }
            func read() -> (URL?, [String: String]) { (url, headers) }
        }
        let capture = Capture()

        let client = WeatherClient(
            baseUrl: "https://example.test",
            apiKey: nil,
            locale: "en",
            http: { url, headers in
                await capture.set(url, headers)
                return (200, "{\"latitude\":0,\"longitude\":0,\"timezone\":\"GMT\"}".data(using: .utf8)!)
            }
        )
        _ = try await client.current(lat: 0, lon: 0, locale: "ar-EG")

        let (u, h) = await capture.read()
        XCTAssertEqual(h["Accept-Language"], "ar-EG")
        XCTAssertNil(h["X-API-Key"])
        let qs = (u.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? [])
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        XCTAssertEqual(qs["locale"], "ar-EG")
    }

    func testThrowsOnNon2xx() async {
        let client = WeatherClient(
            baseUrl: "https://example.test",
            http: { _, _ in (502, "boom".data(using: .utf8)!) }
        )
        do {
            _ = try await client.current(lat: 0, lon: 0)
            XCTFail("expected throw")
        } catch let WeatherError.http(status, _) {
            XCTAssertEqual(status, 502)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
