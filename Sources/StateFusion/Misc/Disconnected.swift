//
//  Disconnected.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 11.06.2026.
//

// This is a helper type to move a non-Sendable value across isolation regions.
@usableFromInline
struct Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
  // This is safe since we take the value as sending and take consumes it
  // and returns it as sending.
  private nonisolated(unsafe) var value: Value?

  @usableFromInline
  init(value: consuming sending Value) {
    self.value = .some(value)
  }

  @usableFromInline
  consuming func take() -> sending Value {
    value.take()!
  }
}
