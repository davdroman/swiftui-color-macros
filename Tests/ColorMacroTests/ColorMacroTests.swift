#if canImport(ColorMacroPlugin)
@testable import ColorMacroPlugin
import MacroTesting
import Testing

@Suite(
	.macros(
		["Color": ColorMacro.self],
		indentationWidth: .tab,
		record: .missing
	)
)
struct ColorMacroTests {
	@Test
	func hexSixDigits() {
		assertMacro {
			"""
			#Color(hex: "#336699")
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 1.0)
			"""
		}
	}

	@Test
	func hexShorthandWithAlpha() {
		assertMacro {
			"""
			#Color(hex: "#0F8C")
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.0, green: 1.0, blue: 0.5333333333333333, opacity: 0.8)
			"""
		}
	}

	@Test
	func rgb() {
		assertMacro {
			"""
			#Color(rgb: 154, 234, 98)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.6039215686274509, green: 0.9176470588235294, blue: 0.3843137254901961, opacity: 1.0)
			"""
		}
	}

	@Test
	func rgba() {
		assertMacro {
			"""
			#Color(rgba: 154, 234, 98, 0.5)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.6039215686274509, green: 0.9176470588235294, blue: 0.3843137254901961, opacity: 0.5)
			"""
		}
	}

	@Test
	func hsl() {
		assertMacro {
			"""
			#Color(hsl: 95, 76, 65)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.6056666666666666, green: 0.9159999999999999, blue: 0.38400000000000006, opacity: 1.0)
			"""
		}
	}

	@Test
	func hsla() {
		assertMacro {
			"""
			#Color(hsla: 32, 100, 50, 0.8)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 1.0, green: 0.5333333333333333, blue: 0.0, opacity: 0.8)
			"""
		}
	}

	@Test
	func hsb() {
		assertMacro {
			"""
			#Color(hsb: 200, 60, 80)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.32000000000000006, green: 0.6399999999999999, blue: 0.8, opacity: 1.0)
			"""
		}
	}

	@Test
	func hsba() {
		assertMacro {
			"""
			#Color(hsba: 200, 60, 80, 0.5)
			"""
		} expansion: {
			"""
			SwiftUI.Color(red: 0.32000000000000006, green: 0.6399999999999999, blue: 0.8, opacity: 0.5)
			"""
		}
	}

	@Test
	func hexInvalidCharacter() {
		assertMacro {
			"""
			#Color(hex: "#GGGGGG")
			"""
		} diagnostics: {
			"""
			#Color(hex: "#GGGGGG")
			            ┬────────
			            ╰─ 🛑 Character 'G' is not valid in a hexadecimal color literal.
			"""
		}
	}

	@Test
	func rgbOutOfRange() {
		assertMacro {
			"""
			#Color(rgb: 300, 0, 0)
			"""
		} diagnostics: {
			"""
			#Color(rgb: 300, 0, 0)
			            ┬──
			            ╰─ 🛑 RGB components must be between 0 and 255, but found 300.0.
			"""
		}
	}

	@Test
	func alphaOutOfRange() {
		assertMacro {
			"""
			#Color(rgba: 0, 0, 0, 2)
			"""
		} diagnostics: {
			"""
			#Color(rgba: 0, 0, 0, 2)
			                      ┬
			                      ╰─ 🛑 Alpha must be between 0 and 1, but found 2.0.
			"""
		}
	}

	@Test
	func nonNumericArgument() {
		assertMacro {
			"""
			let alpha = 0.5
			_ = #Color(rgba: 10, 20, 30, alpha)
			"""
		} diagnostics: {
			"""
			let alpha = 0.5
			_ = #Color(rgba: 10, 20, 30, alpha)
			                             ┬────
			                             ╰─ 🛑 All #Color(rgba:) arguments must be numeric literals.
			"""
		}
	}

	@Test
	func missingLabel() {
		assertMacro {
			"""
			#Color("#FFFFFF")
			"""
		} diagnostics: {
			"""
			#Color("#FFFFFF")
			       ┬────────
			       ╰─ 🛑 Label the first argument to #Color. Supported labels: hex, rgb, rgba, hsl, hsla, hsb, hsba.
			"""
		}
	}
}
#endif
