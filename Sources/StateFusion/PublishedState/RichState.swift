//
//  StateAndData.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

// MARK: - StateAndData

public struct RichState<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable { // ?? RichState | StateCompound
  /// Setter is available via accessHandle
  public fileprivate(set) var state: EnumerableState
  /// Setter is available via accessHandle
  public fileprivate(set) var data: DataState

  public fileprivate(set) var lastEmissionReason: StateAndDataEmissionReason

  // In UML:
  // - State is Enumerable State
  // - CompositeState is a state with nested states (composition)
  // - ExtendedState is additional data that affects state transitions

  public init(state: consuming EnumerableState, data: consuming DataState) {
    self.state = state
    self.data = data
    lastEmissionReason = .initial
  }
}

extension RichState: Copyable where EnumerableState: Copyable, DataState: Copyable {}

extension RichState: Sendable where EnumerableState: Sendable, DataState: Sendable {}

public enum StateAndDataEmissionReason: Equatable, Sendable {
  case initial
  case stateChanged
  case dataChanged
  case stateAndDataChanged
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - AccessHandle

public struct RichStateAccessHandle<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable, ~Escapable {
  public var state: EnumerableState {
    yielding borrow {
      yield _mutableRef.value.state
    }
    yielding mutate {
      isEnumerableStateMutablyAccessed = true // FIXME: - check for correctness doing it such way
      yield &_mutableRef.value.state
    }
  }
  
  public var data: DataState {
    yielding borrow {
      yield _mutableRef.value.data
    }
    yielding mutate {
      isDataStateMutablyAccessed = true
      yield &_mutableRef.value.data
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
  internal consuming func finalizeAccess() -> StateAndDataEmissionReason? {
    let emissionReason: StateAndDataEmissionReason? = switch (isEnumerableStateMutablyAccessed, isDataStateMutablyAccessed) {
    case (false, false): nil
    case (true, false): .stateChanged
    case (false, true): .dataChanged
    case (true, true): .stateAndDataChanged
    }

    if let emissionReason {
      _mutableRef.value.lastEmissionReason = emissionReason
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
    @_unsafeSelfDependentResult
    borrow {
      _mutableRef.value.data
    }
    @_unsafeSelfDependentResult
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

  internal consuming func finalizeAccess() -> StateAndDataEmissionReason? {
    let emissionReason: StateAndDataEmissionReason? = _isDataStateMutablyAccessed ? .dataChanged : nil
    
    if let emissionReason {
      _mutableRef.value.lastEmissionReason = emissionReason
    }

    return emissionReason
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension RichStateDataPropertyAccessHandle: Sendable {}
