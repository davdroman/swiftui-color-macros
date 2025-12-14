import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum ColorVariant: String, CaseIterable {
	case hex
	case rgb
	case rgba
	case hsl
	case hsla
	case hsb
	case hsba

	var expectedArgumentCount: Int {
		switch self {
		case .hex:
			1
		case .rgb, .hsl, .hsb:
			3
		case .rgba, .hsla, .hsba:
			4
		}
	}

	var displayName: String {
		"#Color(\(rawValue):)"
	}

	var componentDescription: String {
		switch self {
		case .rgb, .rgba:
			"RGB components"
		case .hsl, .hsla:
			"HSL components"
		case .hsb, .hsba:
			"HSB components"
		case .hex:
			"Values"
		}
	}

	var includesAlpha: Bool {
		switch self {
		case .rgba, .hsla, .hsba:
			true
		default:
			false
		}
	}
}

private enum ColorMacroDiagnostic: DiagnosticMessage, Error {
	case missingArgument
	case missingLabel
	case unknownLabel(String)
	case unexpectedArgumentCount(label: String, expected: Int, actual: Int)
	case hexNonStringLiteral
	case hexInterpolatedString
	case hexEmpty
	case hexUnsupportedLength(Int)
	case hexInvalidCharacter(Character)
	case invalidNumericLiteral(label: String)
	case valueOutOfRange(description: String, value: Double)

	var severity: DiagnosticSeverity {
		.error
	}

	var message: String {
		switch self {
		case .missingArgument:
			"#Color expects at least one labeled argument."
		case .missingLabel:
			"Label the first argument to #Color. Supported labels: hex, rgb, rgba, hsl, hsla, hsb, hsba."
		case let .unknownLabel(label):
			"Unknown #Color label '\(label)'. Supported labels: hex, rgb, rgba, hsl, hsla, hsb, hsba."
		case let .unexpectedArgumentCount(label, expected, actual):
			"\(label) expects \(expected) argument(s), but received \(actual)."
		case .hexNonStringLiteral:
			"Hex values must be specified as string literals."
		case .hexInterpolatedString:
			"Hex strings cannot contain interpolation or multiple segments."
		case .hexEmpty:
			"Provide at least one hexadecimal digit."
		case let .hexUnsupportedLength(length):
			"Hex literals must contain 3, 4, 6, or 8 digits, but found \(length)."
		case let .hexInvalidCharacter(character):
			"Character '\(character)' is not valid in a hexadecimal color literal."
		case let .invalidNumericLiteral(label):
			"All \(label) arguments must be numeric literals."
		case let .valueOutOfRange(description, value):
			"\(description), but found \(ColorMacroDiagnostic.format(value))."
		}
	}

	var diagnosticID: MessageID {
		MessageID(domain: "ColorMacros", id: "\(self)")
	}

	private static func format(_ value: Double) -> String {
		var text = String(value)
		if !text.contains("."), !text.contains("e"), !text.contains("E") {
			text += ".0"
		}
		return text
	}
}

private struct RGBA {
	let red: Double
	let green: Double
	let blue: Double
	let alpha: Double
}

struct ColorMacro: ExpressionMacro {
	private static let fallbackColor: ExprSyntax = "SwiftUI.Color.clear"

	static func expansion(
		of node: some FreestandingMacroExpansionSyntax,
		in context: some MacroExpansionContext
	) -> ExprSyntax {
		guard let firstArgument = node.arguments.first else {
			diagnose(.missingArgument, at: node.macroName, in: context)
			return fallbackColor
		}

		guard let labelToken = firstArgument.label else {
			diagnose(.missingLabel, at: firstArgument.expression, in: context)
			return fallbackColor
		}

		let label = labelToken.text.lowercased()

		guard let variant = ColorVariant(rawValue: label) else {
			diagnose(.unknownLabel(labelToken.text), at: firstArgument.expression, in: context)
			return fallbackColor
		}

		switch variant {
		case .hex:
			return expandHex(arguments: node.arguments, in: context)
		case .rgb, .rgba:
			return expandRGB(arguments: node.arguments, variant: variant, in: context)
		case .hsl, .hsla:
			return expandHSL(arguments: node.arguments, variant: variant, in: context)
		case .hsb, .hsba:
			return expandHSB(arguments: node.arguments, variant: variant, in: context)
		}
	}

	private static func expandHex(
		arguments: LabeledExprListSyntax,
		in context: some MacroExpansionContext
	) -> ExprSyntax {
		guard arguments.count == 1 else {
			if let expression = arguments.dropFirst().first?.expression {
				diagnose(
					.unexpectedArgumentCount(label: ColorVariant.hex.displayName, expected: 1, actual: arguments.count),
					at: expression,
					in: context
				)
			} else if let first = arguments.first?.expression {
				diagnose(
					.unexpectedArgumentCount(label: ColorVariant.hex.displayName, expected: 1, actual: arguments.count),
					at: first,
					in: context
				)
			}
			return fallbackColor
		}

		guard let literal = arguments.first?.expression.as(StringLiteralExprSyntax.self) else {
			if let expression = arguments.first?.expression {
				diagnose(.hexNonStringLiteral, at: expression, in: context)
			}
			return fallbackColor
		}

		guard
			literal.segments.count == 1,
			case let .stringSegment(segment) = literal.segments.first
		else {
			diagnose(.hexInterpolatedString, at: literal, in: context)
			return fallbackColor
		}

		let trimmed = segment.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
		var sanitized = trimmed

		if sanitized.hasPrefix("#") {
			sanitized.removeFirst()
		}

		if sanitized.lowercased().hasPrefix("0x") {
			sanitized.removeFirst(2)
		}

		guard !sanitized.isEmpty else {
			diagnose(.hexEmpty, at: literal, in: context)
			return fallbackColor
		}

		switch parseHexComponents(from: sanitized) {
		case let .success(components):
			return colorExpression(from: components)
		case let .failure(error):
			diagnose(error, at: literal, in: context)
			return fallbackColor
		}
	}

	private static func expandRGB(
		arguments: LabeledExprListSyntax,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> ExprSyntax {
		guard arguments.count == variant.expectedArgumentCount else {
			let anchor = arguments.last?.expression ?? arguments.first?.expression ?? ExprSyntax(stringLiteral: "")
			diagnose(
				.unexpectedArgumentCount(
					label: variant.displayName,
					expected: variant.expectedArgumentCount,
					actual: arguments.count
				),
				at: anchor,
				in: context
			)
			return fallbackColor
		}

		let channelCount = variant.includesAlpha ? 3 : variant.expectedArgumentCount
		guard let values = integerValues(from: arguments, count: channelCount, variant: variant, in: context) else {
			return fallbackColor
		}

		var alpha = 1.0
		if variant.includesAlpha {
			let alphaIndex = arguments.index(arguments.startIndex, offsetBy: channelCount)
			let alphaExpr = arguments[alphaIndex].expression
			guard let parsedAlpha = parseAlphaLiteral(alphaExpr, variant: variant, in: context) else {
				return fallbackColor
			}
			alpha = parsedAlpha
		}

		let normalized = values.map { Double($0) / 255 }

		let components = RGBA(
			red: normalized[0],
			green: normalized[1],
			blue: normalized[2],
			alpha: alpha
		)

		return colorExpression(from: components)
	}

	private static func expandHSL(
		arguments: LabeledExprListSyntax,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> ExprSyntax {
		let channelCount = variant.includesAlpha ? 3 : variant.expectedArgumentCount
		guard let values = integerValues(from: arguments, count: channelCount, variant: variant, in: context) else {
			return fallbackColor
		}

		let hue = Double(values[0])
		let saturation = Double(values[1])
		let lightness = Double(values[2])

		var alpha = 1.0
		if variant.includesAlpha {
			let alphaIndex = arguments.index(arguments.startIndex, offsetBy: channelCount)
			let alphaExpr = arguments[alphaIndex].expression
			guard let parsedAlpha = parseAlphaLiteral(alphaExpr, variant: variant, in: context) else {
				return fallbackColor
			}
			alpha = parsedAlpha
		}

		let rgb = rgbFromHSL(hueDegrees: hue, saturationPercent: saturation, lightnessPercent: lightness)

		return colorExpression(from: RGBA(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha))
	}

	private static func expandHSB(
		arguments: LabeledExprListSyntax,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> ExprSyntax {
		let channelCount = variant.includesAlpha ? 3 : variant.expectedArgumentCount
		guard let values = integerValues(from: arguments, count: channelCount, variant: variant, in: context) else {
			return fallbackColor
		}

		let hue = Double(values[0])
		let saturation = Double(values[1])
		let brightness = Double(values[2])

		var alpha = 1.0
		if variant.includesAlpha {
			let alphaIndex = arguments.index(arguments.startIndex, offsetBy: channelCount)
			let alphaExpr = arguments[alphaIndex].expression
			guard let parsedAlpha = parseAlphaLiteral(alphaExpr, variant: variant, in: context) else {
				return fallbackColor
			}
			alpha = parsedAlpha
		}

		let rgb = rgbFromHSB(hueDegrees: hue, saturationPercent: saturation, brightnessPercent: brightness)

		return colorExpression(from: RGBA(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha))
	}

	private static func integerValues(
		from arguments: LabeledExprListSyntax,
		count: Int,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> [UInt8]? {
		var values: [UInt8] = []
		var index = arguments.startIndex
		for _ in 0..<count {
			let argument = arguments[index]
			guard let parsed = parseUInt8Literal(argument.expression, variant: variant, in: context) else {
				return nil
			}
			values.append(parsed)
			index = arguments.index(after: index)
		}
		return values
	}

	private static func parseUInt8Literal(
		_ expression: ExprSyntax,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> UInt8? {
		guard let literal = expression.as(IntegerLiteralExprSyntax.self) else {
			diagnose(.invalidNumericLiteral(label: variant.displayName), at: expression, in: context)
			return nil
		}

		let cleaned = literal.literal.text.replacingOccurrences(of: "_", with: "")

		guard let value = Int(cleaned) else {
			diagnose(.invalidNumericLiteral(label: variant.displayName), at: expression, in: context)
			return nil
		}

		guard (0 ... 255).contains(value) else {
			diagnose(
				.valueOutOfRange(
					description: "\(variant.componentDescription) must be between 0 and 255",
					value: Double(value)
				),
				at: expression,
				in: context
			)
			return nil
		}

		return UInt8(value)
	}

	private static func parseAlphaLiteral(
		_ expression: ExprSyntax,
		variant: ColorVariant,
		in context: some MacroExpansionContext
	) -> Double? {
		guard let value = numberLiteralValue(from: expression) else {
			diagnose(.invalidNumericLiteral(label: variant.displayName), at: expression, in: context)
			return nil
		}

		guard (0 ... 1).contains(value) else {
			diagnose(
				.valueOutOfRange(description: "Alpha must be between 0 and 1", value: value),
				at: expression,
				in: context
			)
			return nil
		}

		return value
	}

	private static func numberLiteralValue(from expression: ExprSyntax) -> Double? {
		let trimmed = expression.description
			.replacingOccurrences(of: "_", with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)

		if expression.is(IntegerLiteralExprSyntax.self) || expression.is(FloatLiteralExprSyntax.self) {
			return Double(trimmed)
		}

		if let prefix = expression.as(PrefixOperatorExprSyntax.self),
		   prefix.operator.text == "-",
		   prefix.expression.is(IntegerLiteralExprSyntax.self) || prefix.expression.is(FloatLiteralExprSyntax.self)
		{
			let negative = "-" + prefix.expression.description
				.replacingOccurrences(of: "_", with: "")
				.trimmingCharacters(in: .whitespacesAndNewlines)
			return Double(negative)
		}

		return nil
	}

	private static func parseHexComponents(from hex: String) -> Result<RGBA, ColorMacroDiagnostic> {
		let characters = Array(hex)

		switch characters.count {
		case 3:
			return expandShorthand(digits: characters, includeAlpha: false)
		case 4:
			return expandShorthand(digits: characters, includeAlpha: true)
		case 6:
			return expandFullBytes(characters, includeAlpha: false)
		case 8:
			return expandFullBytes(characters, includeAlpha: true)
		default:
			return .failure(.hexUnsupportedLength(characters.count))
		}
	}

	private static func expandShorthand(
		digits: [Character],
		includeAlpha: Bool
	) -> Result<RGBA, ColorMacroDiagnostic> {
		var values = [UInt8]()
		values.reserveCapacity(digits.count)

		for character in digits {
			guard let nibble = hexValue(of: character) else {
				return .failure(.hexInvalidCharacter(character))
			}
			values.append(nibble)
		}

		let red = values[safe: 0].map { $0 * 17 } ?? 0
		let green = values[safe: 1].map { $0 * 17 } ?? 0
		let blue = values[safe: 2].map { $0 * 17 } ?? 0
		let alphaNibble: UInt8 = includeAlpha ? values[safe: 3] ?? 15 : 15
		let alpha = alphaNibble * 17

		return .success(
			RGBA(
				red: Double(red) / 255,
				green: Double(green) / 255,
				blue: Double(blue) / 255,
				alpha: Double(alpha) / 255
			)
		)
	}

	private static func expandFullBytes(
		_ characters: [Character],
		includeAlpha: Bool
	) -> Result<RGBA, ColorMacroDiagnostic> {
		var bytes = [UInt8]()
		bytes.reserveCapacity(characters.count / 2)

		var index = 0
		while index < characters.count {
			guard let high = hexValue(of: characters[index]) else {
				return .failure(.hexInvalidCharacter(characters[index]))
			}

			guard let low = hexValue(of: characters[index + 1]) else {
				return .failure(.hexInvalidCharacter(characters[index + 1]))
			}

			bytes.append(high << 4 | low)
			index += 2
		}

		let red = bytes[safe: 0] ?? 0
		let green = bytes[safe: 1] ?? 0
		let blue = bytes[safe: 2] ?? 0
		let alpha = includeAlpha ? bytes[safe: 3] ?? 255 : 255

		return .success(
			RGBA(
				red: Double(red) / 255,
				green: Double(green) / 255,
				blue: Double(blue) / 255,
				alpha: Double(alpha) / 255
			)
		)
	}

	private static func rgbFromHSL(
		hueDegrees: Double,
		saturationPercent: Double,
		lightnessPercent: Double
	) -> (red: Double, green: Double, blue: Double) {
		var hue = hueDegrees.truncatingRemainder(dividingBy: 360)
		if hue < 0 { hue += 360 }
		let h = hue / 360
		let s = saturationPercent / 100
		let l = lightnessPercent / 100

		let c = (1 - abs(2 * l - 1)) * s
		let hPrime = h * 6
		let x = c * (1 - abs(hPrime.truncatingRemainder(dividingBy: 2) - 1))
		let m = l - c / 2

		let (r1, g1, b1): (Double, Double, Double)
		switch hPrime {
		case ..<1:
			(r1, g1, b1) = (c, x, 0)
		case ..<2:
			(r1, g1, b1) = (x, c, 0)
		case ..<3:
			(r1, g1, b1) = (0, c, x)
		case ..<4:
			(r1, g1, b1) = (0, x, c)
		case ..<5:
			(r1, g1, b1) = (x, 0, c)
		default:
			(r1, g1, b1) = (c, 0, x)
		}

		return (r1 + m, g1 + m, b1 + m)
	}

	private static func rgbFromHSB(
		hueDegrees: Double,
		saturationPercent: Double,
		brightnessPercent: Double
	) -> (red: Double, green: Double, blue: Double) {
		var hue = hueDegrees.truncatingRemainder(dividingBy: 360)
		if hue < 0 { hue += 360 }
		let h = hue / 60
		let s = saturationPercent / 100
		let v = brightnessPercent / 100

		let c = v * s
		let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
		let m = v - c

		let (r1, g1, b1): (Double, Double, Double)
		switch h {
		case ..<1:
			(r1, g1, b1) = (c, x, 0)
		case ..<2:
			(r1, g1, b1) = (x, c, 0)
		case ..<3:
			(r1, g1, b1) = (0, c, x)
		case ..<4:
			(r1, g1, b1) = (0, x, c)
		case ..<5:
			(r1, g1, b1) = (x, 0, c)
		default:
			(r1, g1, b1) = (c, 0, x)
		}

		return (r1 + m, g1 + m, b1 + m)
	}

	private static func colorExpression(from components: RGBA) -> ExprSyntax {
		let red = literal(for: components.red)
		let green = literal(for: components.green)
		let blue = literal(for: components.blue)
		let alpha = literal(for: components.alpha)

		return """
		SwiftUI.Color(red: \(raw: red), green: \(raw: green), blue: \(raw: blue), opacity: \(raw: alpha))
		"""
	}

	private static func literal(for value: Double) -> String {
		var text = String(value)
		if !text.contains("."), !text.contains("e"), !text.contains("E") {
			text += ".0"
		}
		return text
	}

	private static func hexValue(of character: Character) -> UInt8? {
		guard let scalar = character.unicodeScalars.first, scalar.isASCII else {
			return nil
		}

		switch scalar.value {
		case 48...57: // 0-9
			return UInt8(scalar.value - 48)
		case 65...70: // A-F
			return UInt8(scalar.value - 55)
		case 97...102: // a-f
			return UInt8(scalar.value - 87)
		default:
			return nil
		}
	}

	private static func diagnose(
		_ message: ColorMacroDiagnostic,
		at node: some SyntaxProtocol,
		in context: some MacroExpansionContext
	) {
		context.diagnose(Diagnostic(node: Syntax(node), message: message))
	}
}

extension Array {
	fileprivate subscript(safe index: Int) -> Element? {
		guard indices.contains(index) else { return nil }
		return self[index]
	}
}

@main
struct ColorMacrosCompilerPlugin: CompilerPlugin {
	let providingMacros: [any Macro.Type] = [
		ColorMacro.self,
	]
}
