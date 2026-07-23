//
//  Publisher+DenestifyTuple.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 23.07.2026.
//

// MARK: - Denestify

// All tuple nesting combinations for arity 3, 4, and 5.

// swiftlint:disable large_tuple

// MARK: - 3 Parameters (2 patterns)

@inlinable @_transparent // inlining give 5%-20x performance gain, depending on values passed
public func denestify<A, B, C>(tuple: ((A, B), C)) -> (A, B, C) {
  let ((a, b), c) = tuple
  return (a, b, c)
}

@inlinable @_transparent
public func denestify<A, B, C>(tuple: (A, (B, C))) -> (A, B, C) {
  let (a, (b, c)) = tuple
  return (a, b, c)
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - 4 Parameters (10 patterns)

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (((A, B), C), D)) -> (A, B, C, D) {
  let (((a, b), c), d) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: ((A, (B, C)), D)) -> (A, B, C, D) {
  let ((a, (b, c)), d) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: ((A, B), (C, D))) -> (A, B, C, D) {
  let ((a, b), (c, d)) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: ((A, B), C, D)) -> (A, B, C, D) {
  let ((a, b), c, d) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: ((A, B, C), D)) -> (A, B, C, D) {
  let ((a, b, c), d) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (A, ((B, C), D))) -> (A, B, C, D) {
  let (a, ((b, c), d)) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (A, (B, (C, D)))) -> (A, B, C, D) {
  let (a, (b, (c, d))) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (A, (B, C), D)) -> (A, B, C, D) {
  let (a, (b, c), d) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (A, (B, C, D))) -> (A, B, C, D) {
  let (a, (b, c, d)) = tuple
  return (a, b, c, d)
}

@inlinable @_transparent
public func denestify<A, B, C, D>(tuple: (A, B, (C, D))) -> (A, B, C, D) {
  let (a, b, (c, d)) = tuple
  return (a, b, c, d)
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - 5 Parameters (37 patterns)

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((((A, B), C), D), E)) -> (A, B, C, D, E) {
  let ((((a, b), c), d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (((A, (B, C)), D), E)) -> (A, B, C, D, E) {
  let (((a, (b, c)), d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (((A, B), (C, D)), E)) -> (A, B, C, D, E) {
  let (((a, b), (c, d)), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (((A, B), C), (D, E))) -> (A, B, C, D, E) {
  let (((a, b), c), (d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (((A, B), C), D, E)) -> (A, B, C, D, E) {
  let (((a, b), c), d, e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (((A, B), C, D), E)) -> (A, B, C, D, E) {
  let (((a, b), c, d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, ((B, C), D)), E)) -> (A, B, C, D, E) {
  let ((a, ((b, c), d)), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, (B, (C, D))), E)) -> (A, B, C, D, E) {
  let ((a, (b, (c, d))), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, (B, C)), (D, E))) -> (A, B, C, D, E) {
  let ((a, (b, c)), (d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, (B, C)), D, E)) -> (A, B, C, D, E) {
  let ((a, (b, c)), d, e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, (B, C, D)), E)) -> (A, B, C, D, E) {
  let ((a, (b, c, d)), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), ((C, D), E))) -> (A, B, C, D, E) {
  let ((a, b), ((c, d), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), (C, (D, E)))) -> (A, B, C, D, E) {
  let ((a, b), (c, (d, e))) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), (C, D), E)) -> (A, B, C, D, E) {
  let ((a, b), (c, d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), (C, D, E))) -> (A, B, C, D, E) {
  let ((a, b), (c, d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), C, (D, E))) -> (A, B, C, D, E) {
  let ((a, b), c, (d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B), C, D, E)) -> (A, B, C, D, E) {
  let ((a, b), c, d, e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B, C), (D, E))) -> (A, B, C, D, E) {
  let ((a, b, c), (d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B, C), D, E)) -> (A, B, C, D, E) {
  let ((a, b, c), d, e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: ((A, B, C, D), E)) -> (A, B, C, D, E) {
  let ((a, b, c, d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (((B, C), D), E))) -> (A, B, C, D, E) {
  let (a, (((b, c), d), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, ((B, (C, D)), E))) -> (A, B, C, D, E) {
  let (a, ((b, (c, d)), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, ((B, C), (D, E)))) -> (A, B, C, D, E) {
  let (a, ((b, c), (d, e))) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, ((B, C), D), E)) -> (A, B, C, D, E) {
  let (a, ((b, c), d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, ((B, C, D), E))) -> (A, B, C, D, E) {
  let (a, ((b, c, d), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, ((C, D), E)))) -> (A, B, C, D, E) {
  let (a, (b, ((c, d), e))) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, (C, D)), E)) -> (A, B, C, D, E) {
  let (a, (b, (c, d)), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, (C, D), E))) -> (A, B, C, D, E) {
  let (a, (b, (c, d), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, C), (D, E))) -> (A, B, C, D, E) {
  let (a, (b, c), (d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, C), D, E)) -> (A, B, C, D, E) {
  let (a, (b, c), d, e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, C, D), E)) -> (A, B, C, D, E) {
  let (a, (b, c, d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, (B, C, D, E))) -> (A, B, C, D, E) {
  let (a, (b, c, d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, B, ((C, D), E))) -> (A, B, C, D, E) {
  let (a, b, ((c, d), e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, B, (C, (D, E)))) -> (A, B, C, D, E) {
  let (a, b, (c, (d, e))) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, B, (C, D), E)) -> (A, B, C, D, E) {
  let (a, b, (c, d), e) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, B, (C, D, E))) -> (A, B, C, D, E) {
  let (a, b, (c, d, e)) = tuple
  return (a, b, c, d, e)
}

@inlinable @_transparent
public func denestify<A, B, C, D, E>(tuple: (A, B, C, (D, E))) -> (A, B, C, D, E) {
  let (a, b, c, (d, e)) = tuple
  return (a, b, c, d, e)
}

// MARK: - Publisher + Denestify

// swiftlint:enable large_tuple
