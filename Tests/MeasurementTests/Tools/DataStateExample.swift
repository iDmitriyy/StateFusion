//
//  DataState_Example.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 22.07.2026.
//

@available(anyAppleOS 26.0, *)
struct DataState_Example {
  var number: Int = 0
  var title: String = "12345678901234567890"
  var text: String = "12345678901234567890"
  var array: [Int] = [1, 2, 3, 4, 5]
  var dict: [String: Int] = ["1": 1, "2": 2, "3": 3, "4": 4, "5": 5]
  var iarray = InlineArray<25, String>(repeating: "")
}

@available(anyAppleOS 26.0, *)
struct DataState_SendableExample: Sendable {
  var number: Int = 0
  var title: String = "12345678901234567890"
  var text: String = "12345678901234567890"
  var array: [Int] = [1, 2, 3, 4, 5]
  var dict: [String: Int] = ["1": 1, "2": 2, "3": 3, "4": 4, "5": 5]
  var iarray = InlineArray<25, String>(repeating: "")
}
