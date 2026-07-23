//
//  PrintTable.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 21.07.2026.
//

import Foundation

/// Prints a table with and 2 columns: name & value
///
/// Example:
/// ```
///       TableName
/// ──────────────────────
/// inoutAccess    37.59
/// pointerAccess  41.50
/// ```
func printTable(_ title: String,
                fractionDigits: UInt8 = 0,
                rows: [(name: String, value: Double)]) {
  // Helper function to format Double values with underscore thousand separators
  func formatValue(_ value: Double) -> String {
    let formatter = groupingSize3Formatter(maxFractionDigits: fractionDigits)
    let formatted = formatter.string(from: value as NSNumber) ?? String(format: "%.\(fractionDigits)f", value)
    return formatted.replacingOccurrences(of: formatter.groupingSeparator ?? ",", with: "_")
  }
  
  let formatted = rows.map { ($0.name, formatValue($0.value)) }
  let nameWidth = formatted.map(\.0.count).max() ?? 0
  let valueWidth = formatted.map(\.1.count).max() ?? 0
  let tableWidth = nameWidth + valueWidth + 4
  let separator = String(repeating: "─", count: tableWidth)
  
  let titlePadding = String(repeating: " ", count: max(0, (tableWidth - title.count) / 2))
  
  print("")
  print("\(titlePadding)\(title)")
  print(separator)
  for (name, value) in formatted {
    let pad = String(repeating: " ", count: max(0, valueWidth - value.count))
    print("\(name.padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \(pad)\(value)")
  }
  print("")
}

func groupingSize3Formatter(maxFractionDigits: UInt8) -> NumberFormatter {
  let formatter = NumberFormatter()
  formatter.usesGroupingSeparator = true
  formatter.groupingSize = 3
  formatter.maximumFractionDigits = Int(maxFractionDigits)
  formatter.locale = .current
  return formatter
}
