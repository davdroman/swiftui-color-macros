public import SwiftUI

@freestanding(expression)
public macro Color(hex literal: String) -> SwiftUI.Color = #externalMacro(
	module: "ColorMacrosPlugin",
	type: "ColorMacro"
)

@freestanding(expression)
public macro Color(rgb red: UInt8, _ green: UInt8, _ blue: UInt8) -> SwiftUI.Color = #externalMacro(
	module: "ColorMacrosPlugin",
	type: "ColorMacro"
)

@freestanding(expression)
public macro Color(rgba red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: Double) -> SwiftUI.Color =
	#externalMacro(
		module: "ColorMacrosPlugin",
		type: "ColorMacro"
	)

@freestanding(expression)
public macro Color(hsl hue: UInt8, _ saturation: UInt8, _ lightness: UInt8) -> SwiftUI.Color = #externalMacro(
	module: "ColorMacrosPlugin",
	type: "ColorMacro"
)

@freestanding(expression)
public macro Color(hsla hue: UInt8, _ saturation: UInt8, _ lightness: UInt8, _ alpha: Double) -> SwiftUI.Color =
	#externalMacro(
		module: "ColorMacrosPlugin",
		type: "ColorMacro"
	)

@freestanding(expression)
public macro Color(hsb hue: UInt8, _ saturation: UInt8, _ brightness: UInt8) -> SwiftUI.Color = #externalMacro(
	module: "ColorMacrosPlugin",
	type: "ColorMacro"
)

@freestanding(expression)
public macro Color(hsba hue: UInt8, _ saturation: UInt8, _ brightness: UInt8, _ alpha: Double) -> SwiftUI.Color =
	#externalMacro(
		module: "ColorMacrosPlugin",
		type: "ColorMacro"
	)
