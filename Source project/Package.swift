// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PersonalBudget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BudgetCore", targets: ["BudgetCore"]),
        .executable(name: "PersonalBudget", targets: ["BudgetApp"])
    ],
    targets: [
        .target(name: "BudgetCore"),
        .executableTarget(name: "BudgetApp", dependencies: ["BudgetCore"]),
        .testTarget(name: "BudgetCoreTests", dependencies: ["BudgetCore"])
    ]
)
