// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "StateFusion",
  platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .macCatalyst(.v18), .watchOS(.v11), .visionOS(.v2)],
  products: [
    .library(name: "StateFusion", targets: ["StateFusion"]),
  ],
  targets: [
    .target(name: "StateFusion"),
    .testTarget(name: "StateFusionTests", dependencies: ["StateFusion"]),
    .testTarget(name: "MeasurementTests", dependencies: [.target(name: "StateFusion")]),
//    .executableTarget(name: "MeasurementsExecutable", dependencies: [.target(name: "StateFusion")])
  ],
  swiftLanguageModes: [.v6],
)

for target: PackageDescription.Target in package.targets {
  {
    var settings: [PackageDescription.SwiftSetting] = $0 ?? []
    settings.append(.enableUpcomingFeature("ExistentialAny"))
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))
    settings.append(.enableExperimentalFeature("Lifetimes"))
    settings.append(.enableExperimentalFeature("LifetimeDependence"))
    settings.append(.enableExperimentalFeature("MoveOnlyTuples"))
    settings.append(.enableExperimentalFeature("StaticExclusiveOnly"))
    settings.append(.enableExperimentalFeature("CoroutineAccessors"))
    settings.append(.enableExperimentalFeature("BuiltinModule"))
    
    $0 = settings
  }(&target.swiftSettings)
}

//let swiftFlags = [
//  "-Xfrontend", "-disable-reflection-metadata",
//  "-Xfrontend", "-disable-reflection-names",
//]
