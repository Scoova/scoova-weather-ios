# Changelog

All notable changes to `ScoovaWeather` are documented here.

## 1.1.1 — 2026-05-25
- Default `baseUrl` switched from the retired `https://weather.scoo-va.info` subdomain to the central gateway at `https://api.scoo-va.info/api/v1/weather`. Callers who explicitly set `baseUrl` are unaffected. The old subdomain returns `ENDPOINT_RETIRED`.

## 1.1.0 — 2026-05-25

- Initial public release of the standalone Swift package
  `Scoova/scoova-weather-ios`. Lifts the legacy unified-SDK
  `WeatherAPI` namespace out of `ScoovaSDK` into its own product.
- API surface parity with `@scoova/weather` (web), `scoova-weather-android`,
  `scoova-weather-react-native`, and `scoova_weather` (Flutter):
  `WeatherClient` with `current()`, `hourly()`, `daily()`,
  `forecast()`, `raw()`, plus `decodeWeatherCode()`.
- **Locale built in:** BCP-47 codes — `en`, `en-US`, `fr`, `es`, `de`,
  `it`, `pt-BR`, `nl`, `ar`, `ar-EG`, `ar-SA`, plus regional variants.
  Sent as both `?locale=` and `Accept-Language`. Per-call `locale`
  overrides the client default.
- **API key built in:** `apiKey` constructor parameter auto-attaches
  `X-API-Key` to every request. Reads `SCOOVA_API_KEY` from
  `ProcessInfo.processInfo.environment` when no value is passed.
- Platforms: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+.
