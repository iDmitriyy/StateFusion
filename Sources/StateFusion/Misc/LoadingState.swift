//
//  LoadingState.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

@frozen
public enum LoadingState<D, E: Error> {
  case isLoading
  case dataLoaded(D)
  case loadingError(E)
}

extension LoadingState: Sendable where D: Sendable {}
