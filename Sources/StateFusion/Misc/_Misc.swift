//
//  _Misc.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine

extension Publisher where Failure == Never {
  /// Activates the publisher chain by subscribing to it and ignoring emitted values.
  /// Made for convenience and is equal to `sink(receiveValue: { _ in })` call.
  ///
  /// - Returns: An `AnyCancellable` instance that controls the subscription's lifecycle.
  @_transparent
  internal func subscribe() -> AnyCancellable {
    sink(receiveValue: { _ in })
  }
}

// MARK: - CancellationBag + Swift.Task

extension CancellationBag {
  /// Task will be cancelled when CancellationBag deinited. e.g. when screen closed
  @inline(always)
  public func insert<Success, Failure>(_ task: Task<Success, Failure>) {
    let anyCancellable = AnyCancellable {
      task.cancel()
    }
    // TODO: - add example to App for autoCancellation network request
    insert(anyCancellable)
  }
}

extension Task {
  @inline(always)
  public func store(in bag: borrowing CancellationBag) {
    bag.insert(self)
  }
}

/*
 TODO:
 - passing existential to generic func args can make unneeded unpacking. Check places where unpacking is redundant.
 
 */
