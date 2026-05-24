// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScoovaWeather",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "ScoovaWeather",
            targets: ["ScoovaWeather"]
        ),
    ],
    targets: [
        .target(
            name: "ScoovaWeather",
            path: "Sources/ScoovaWeather"
        ),
        .testTarget(
            name: "ScoovaWeatherTests",
            dependencies: ["ScoovaWeather"],
            path: "Tests/ScoovaWeatherTests"
        ),
    ]
)
