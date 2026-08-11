// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SalaryCharger",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SalaryCharger", targets: ["SalaryCharger"])
    ],
    targets: [
        .executableTarget(
            name: "SalaryCharger",
            path: "Sources/SalaryCharger"
        ),
        .testTarget(
            name: "SalaryChargerTests",
            dependencies: ["SalaryCharger"],
            path: "Tests/SalaryChargerTests"
        )
    ]
)
