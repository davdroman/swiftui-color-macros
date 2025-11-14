// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "swiftui-color-macros",
	platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
	products: [
		.library(
			name: "ColorMacros",
			targets: ["ColorMacros"]
		),
	],
	dependencies: [],
	targets: [
		.macro(
			name: "ColorMacrosPlugin",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
				.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
			]
		),

		.target(name: "ColorMacros", dependencies: ["ColorMacrosPlugin"]),

		.testTarget(
			name: "ColorMacrosTests",
			dependencies: [
				"ColorMacros",
				"ColorMacrosPlugin",
				.product(name: "MacroTesting", package: "swift-macro-testing"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
	]
)

package.dependencies += [
	.package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
	.package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
]

for target in package.targets {
	target.swiftSettings = target.swiftSettings ?? []
	target.swiftSettings? += [
		.enableUpcomingFeature("ExistentialAny"),
		.enableUpcomingFeature("InternalImportsByDefault"),
	]
}
