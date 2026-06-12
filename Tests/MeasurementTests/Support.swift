//
//  Support.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 12.06.2026.
//

@inlinable
@inline(__always)
@discardableResult
internal func performMeasuredAction<T>(count: Int, _ actions: () -> T) -> (results: [T], duration: Double) {
  let clock = ContinuousClock()
    
  var results: [T] = []
  
  var totalDuration = Duration.zero
  for _ in 0..<count {
    let initialTime = clock.now
    let result = actions()
    let endTime = clock.now
    let difference = endTime - initialTime
    totalDuration += difference
    results.append(result)
  }
  
  let ms = totalDuration.inMilliseconds
  
  return (results, ms)
}

@inline(never) @_optimize(none)
public func blackHole<T>(_ thing: T) {
  _ = thing
}

@inline(never) @_optimize(none)
public func blackHole<T: ~Copyable & ~Escapable>(consuming thing: consuming T) {
  _ = thing
}

extension Duration {
  @usableFromInline internal var inNanoseconds: Double {
    let (seconds, attoseconds) = components
    return Double(seconds) * 1_000_000_000 + Double(attoseconds) * 1e-9
  }
  
  @usableFromInline internal var inMicroseconds: Double {
    let (seconds, attoseconds) = components
    return Double(seconds) * 1_000_000 + Double(attoseconds) * 1e-12
  }
  
  @usableFromInline internal var inMilliseconds: Double {
    let (seconds, attoseconds) = components
    return Double(seconds) * 1000 + Double(attoseconds) * 1e-15
  }
  
  @usableFromInline internal var inSeconds: Double {
    let (seconds, attoseconds) = components
    return Double(seconds) + Double(attoseconds) * 1e-18
  }
}
