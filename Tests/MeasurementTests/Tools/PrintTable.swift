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
///```
///       TableName
/// ──────────────────────
/// inoutAccess    37.59
/// pointerAccess  41.50
///```
func printTable(_ title: String,
                rows: [(name: String, value: Double)],
                decimalPlaces: Int = 2) {
  let formatted = rows.map { ($0.name, String(format: "%.*f", decimalPlaces, Double($0.value))) }
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
