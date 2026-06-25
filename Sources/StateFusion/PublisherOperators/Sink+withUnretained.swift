//
//  Sink+withUnretained.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

extension Publisher where Failure == Never {
  public func sink<Object: AnyObject>(withUnretained object: Object,
                                      receiveValue: @escaping (Object, Self.Output) -> Void) -> AnyCancellable {
    sink(receiveValue: { [weak object] value in
      guard let object else { return }
      receiveValue(object, value)
    })
  }
}

extension Publisher where Output == Void, Failure == Never {
  public func sink<Object: AnyObject>(withUnretained object: Object,
                                      receiveValue: @escaping (Object) -> Void) -> AnyCancellable {
    sink(receiveValue: { [weak object] _ in
      guard let object else { return }
      receiveValue(object)
    })
  }
}
