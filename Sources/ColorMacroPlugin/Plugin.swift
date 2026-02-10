import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacroPlugin: CompilerPlugin {
	let providingMacros: [any Macro.Type] = [
		ColorMacro.self,
	]
}
