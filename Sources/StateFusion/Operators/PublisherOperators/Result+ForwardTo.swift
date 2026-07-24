//
//  Result+ForwardTo.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 24.07.2026.
//

extension Result {
  @inlinable @inline(always)
  public func forward(successTo successSubject: some Combine.Subject<Success, Never>,
                      failureTo errorSubject: some Combine.Subject<Failure, Never>) {
    switch self {
    case .success(let element): successSubject.send(element)
    case .failure(let error): errorSubject.send(error)
    }
  }

  @inlinable @inline(always)
  public func forward(successTo successSubject: PublishedEvent<Success>,
                      failureTo errorSubject: PublishedEvent<Failure>) {
    switch self {
    case .success(let element): successSubject.send(element)
    case .failure(let error): errorSubject.send(error)
    }
  }
}
