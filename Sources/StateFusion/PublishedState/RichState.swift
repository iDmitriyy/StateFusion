//
//  StateAndData.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

// MARK: - StateAndData

public struct RichState<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable { // ?? RichState | StateCompound
  /// Setter is unavailable. To update value use accessHandle
  public fileprivate(set) var state: EnumerableState
  /// Setter is unavailable. To update value use accessHandle
  public fileprivate(set) var data: DataState

  public fileprivate(set) var lastWrite: RichStateWriteKind

  // In UML:
  // - State is Enumerable State
  // - CompositeState is a state with nested states (composition)
  // - ExtendedState is additional data that affects state transitions

  public init(state: consuming EnumerableState, data: consuming DataState) {
    self.state = state
    self.data = data
    lastWrite = .initial
  }
}

extension RichState: Copyable where EnumerableState: Copyable, DataState: Copyable {}

extension RichState: Sendable where EnumerableState: Sendable, DataState: Sendable {}

extension RichState: Equatable where EnumerableState: Equatable, DataState: Equatable {}

public enum RichStateWriteKind: Equatable, Sendable {
  case initial
  case state
  case data
  case both
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - AccessHandle

public struct RichStateAccessHandle<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable, ~Escapable {
  public var state: EnumerableState {
    borrow {
      _mutableRef.value.state
    }
    mutate {
      isEnumerableStateMutablyAccessed = true // FIXME: - check for correctness doing it such way
      return &_mutableRef.value.state
    }
  }

  public var data: DataState {
    borrow {
      _mutableRef.value.data
    }
    mutate {
      isDataStateMutablyAccessed = true
      return &_mutableRef.value.data
    }
  }

  // We can only observe that storage is mutably accessed, but not prove changing really happened.
  // e.g. someone can write $0.data.searchText = $0.data.searchText – the data is mutated, but it stay the same.
  // Such cases are not expected in real cases though.
  // PS: you can use .removeDuplicates() operator for additional guarantees and emission elimination if needed.

  private var isEnumerableStateMutablyAccessed: Bool = false
  private var isDataStateMutablyAccessed: Bool = false

  /// private
  @usableFromInline
  /* private */ internal var _mutableRef: _MutableRef<RichState<EnumerableState, DataState>>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming _MutableRef<RichState<EnumerableState, DataState>>) {
    _mutableRef = mutableRef
  }

  @usableFromInline
  internal consuming func finalizeAccess() -> RichStateWriteKind? {
    let emissionReason: RichStateWriteKind? = switch (isEnumerableStateMutablyAccessed, isDataStateMutablyAccessed) {
    case (false, false): nil
    case (true, false): .state
    case (false, true): .data
    case (true, true): .both
    }

    if let emissionReason {
      _mutableRef.value.lastWrite = emissionReason
    }

    return emissionReason
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension RichStateAccessHandle: Sendable {}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Data Property AccessHandle

public struct RichStateDataPropertyAccessHandle<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable, ~Escapable {
  public var data: DataState {
    borrow {
      _mutableRef.value.data
    }
    mutate {
      _isDataStateMutablyAccessed = true
      return &_mutableRef.value.data
    }
  }

  private var _isDataStateMutablyAccessed: Bool = false

  /// private
  @usableFromInline
  /* private */ internal var _mutableRef: _MutableRef<RichState<EnumerableState, DataState>>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming _MutableRef<RichState<EnumerableState, DataState>>) {
    _mutableRef = mutableRef
  }

  internal consuming func finalizeAccess() -> RichStateWriteKind? {
    let emissionReason: RichStateWriteKind? = _isDataStateMutablyAccessed ? .data : nil

    if let emissionReason {
      _mutableRef.value.lastWrite = emissionReason
    }

    return emissionReason
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension RichStateDataPropertyAccessHandle: Sendable {}
