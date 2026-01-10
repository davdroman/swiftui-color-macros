# `#Color`

[![CI](https://github.com/davdroman/swiftui-color-macro/actions/workflows/ci.yml/badge.svg)](https://github.com/davdroman/swiftui-color-macro/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdavdroman%2Fswiftui-color-macro%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/davdroman/swiftui-color-macro)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdavdroman%2Fswiftui-color-macro%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/davdroman/swiftui-color-macro)

`ColorMacro` is a bundle of expression macros that turn the color tokens you copy from
Figma/Sketch into compile-time `SwiftUI.Color` literals:

```swift
import SwiftUI
import ColorMacro

let brand = #Color(hex: "#FF9900")
let overlay = #Color(hex: "0x336699CC")
let grass = #Color(rgba: 154, 234, 98, 1)
let warning = #Color(hsla: 32, 100, 50, 0.8)
let accent = #Color(hsba: 200, 60, 80, 0.65)
```

## Features

- `hex:` accepts `RGB`, `RGBA`, `RRGGBB`, `RRGGBBAA`, with or without `#` or a `0x` prefix.
- `rgb:` / `rgba:` accept 0–255 integer channels, optionally plus opacity (0–1).
- `hsl:` / `hsla:` accept degrees/percentages, matching what design tools output.
- `hsb:` / `hsba:` cover hue–saturation–brightness (%), again with optional opacity.
- Every variant emits a `SwiftUI.Color` literal (no runtime helpers) and validates inputs at build time.

Example diagnostic:

```
#Color(hex: "#12345")
            ┬───────
            ╰─ 🛑 Hex literals must contain 3, 4, 6, or 8 digits, but found 5.
```

## Installation

Add the package to your project:

```swift
dependencies: [
  .package(url: "https://github.com/davdroman/swiftui-color-macro.git", from: "0.1.0")
],
targets: [
  .target(
    name: "App",
    dependencies: [
      .product(name: "ColorMacro", package: "swiftui-color-macro")
    ]
  )
]
```

Then import the module alongside SwiftUI wherever you need the macro.
