//
//  Publisher+CompactMap.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 24.07.2026.
//

extension Publisher {
  public func compactMap<R>() -> Publishers.CompactMap<Self, R> where Output == R? {
    compactMap { $0 }
  }
}
