# ScoovaWeather (Swift)

Open-meteo compatible Swift client for `weather.scoo-va.info`. SwiftPM
library targeting iOS 15+, macOS 12+, tvOS 15+, watchOS 8+.

## Install

In your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Scoova/scoova-weather-ios.git", from: "1.1.1"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "ScoovaWeather", package: "scoova-weather-ios"),
        ]
    ),
]
```

In Xcode: *File → Add Package Dependencies…* and paste
`https://github.com/Scoova/scoova-weather-ios`.

## Usage

```swift
import ScoovaWeather

// Unauthenticated against the raw subdomain.
let client = WeatherClient()

// Authenticated via the gateway, French copy.
let gateway = WeatherClient(
    baseUrl: "https://api.scoo-va.info/v1/weather",
    apiKey: ProcessInfo.processInfo.environment["SCOOVA_API_KEY"] ?? "demo",
    locale: "fr"
)

let now = try await gateway.current(lat: 30.04, lon: 31.24)
let condition = decodeWeatherCode(now.current?["weather_code"] as? Int)

let daily = try await gateway.daily(
    lat: 30.04, lon: 31.24,
    vars: [.temperature2mMax, .temperature2mMin, .precipitationSum],
    days: 5
)

// Per-call locale overrides the client default.
let arabic = try await gateway.current(lat: 30.04, lon: 31.24, locale: "ar-EG")
```

## Locale

`locale` accepts BCP-47 codes: `en`, `en-US`, `en-GB`, `fr`, `es`, `de`, `it`,
`pt-BR`, `nl`, `ar`, `ar-EG`, `ar-SA`, plus regional variants. Sent as both
`?locale=` query string and `Accept-Language` header. Unsupported codes fall
back to `en` server-side.

## Tests

```sh
swift test
```

## License

Apache-2.0.
