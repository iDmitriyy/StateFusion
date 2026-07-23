//
//  Publisher+DenestifyTuple.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 23.07.2026.
//

// MARK: - Denestify

// swiftlint:disable large_tuple

// MARK: - 3 Parameters

public func denestify<A, B, C>(tuple: ((A, B), C)) -> (A, B, C) {
  let ((a, b), c) = tuple
  return (a, b, c)
}

public func denestify<A, B, C>(tuple: (A, (B, C))) -> (A, B, C) {
  let (a, (b, c)) = tuple
  return (a, b, c)
}

// MARK: - 4 Parameters

public func denestify<A, B, C, D>(tuple: (A, (B, C, D))) -> (A, B, C, D) {
  let (A, (B, C, D)) = tuple
  return (A, B, C, D)
}

public func denestify<A, B, C, D>(tuple: ((A, B), (C, D))) -> (A, B, C, D) {
  let ((A, B), (C, D)) = tuple
  return (A, B, C, D)
}

public func denestify<A, B, C, D>(tuple: ((A, B, C), D)) -> (A, B, C, D) {
  let ((A, B, C), D) = tuple
  return (A, B, C, D)
}

public func denestify<A, B, C, D>(tuple: (A, B, (C, D))) -> (A, B, C, D) {
  let (A, B, (C, D)) = tuple
  return (A, B, C, D)
}

public func denestify<A, B, C, D>(tuple: (A, (B, C), D)) -> (A, B, C, D) {
  let (A, (B, C), D) = tuple
  return (A, B, C, D)
}

public func denestify<A, B, C, D>(tuple: ((A, B), C, D)) -> (A, B, C, D) {
  let ((A, B), C, D) = tuple
  return (A, B, C, D)
}

// 📝 @iDmitriyy
// iDmitriyy_TODO: - не учтённый генератором вариант. Доработать чтоб были все варианты.
public func denestify<A, B, C, D>(tuple: (((A, B), C), D)) -> (A, B, C, D) {
  let (((A, B), C), D) = tuple
  return (A, B, C, D)
}

// MARK: - 5 Parameters

public func denestify<A, B, C, D, E>(tuple: (A, (B, C, D, E))) -> (A, B, C, D, E) {
  let (A, (B, C, D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B), (C, D, E))) -> (A, B, C, D, E) {
  let ((A, B), (C, D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B, C), (D, E))) -> (A, B, C, D, E) {
  let ((A, B, C), (D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B, C, D), E)) -> (A, B, C, D, E) {
  let ((A, B, C, D), E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, B, (C, D, E))) -> (A, B, C, D, E) {
  let (A, B, (C, D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, (B, C), (D, E))) -> (A, B, C, D, E) {
  let (A, (B, C), (D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, (B, C, D), E)) -> (A, B, C, D, E) {
  let (A, (B, C, D), E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B), C, (D, E))) -> (A, B, C, D, E) {
  let ((A, B), C, (D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B), (C, D), E)) -> (A, B, C, D, E) {
  let ((A, B), (C, D), E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B, C), D, E)) -> (A, B, C, D, E) {
  let ((A, B, C), D, E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, B, C, (D, E))) -> (A, B, C, D, E) {
  let (A, B, C, (D, E)) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, B, (C, D), E)) -> (A, B, C, D, E) {
  let (A, B, (C, D), E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (A, (B, C), D, E)) -> (A, B, C, D, E) {
  let (A, (B, C), D, E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: ((A, B), C, D, E)) -> (A, B, C, D, E) {
  let ((A, B), C, D, E) = tuple
  return (A, B, C, D, E)
}

public func denestify<A, B, C, D, E>(tuple: (((A, B, C), D), E)) -> (A, B, C, D, E) {
  let (((a, b, c), d), e) = tuple
  return (a, b, c, d, e)
}

// MARK: - Publisher + Denestify


// swiftlint:enable large_tuple
