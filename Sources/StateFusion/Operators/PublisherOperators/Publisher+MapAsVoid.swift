//
//  Publisher+MapAsVoid.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 24.07.2026.
//

extension Publisher {
  public func mapAsVoid() -> Publishers.Map<Self, Void> {
    self.map { _ in Void() }
  }
}
