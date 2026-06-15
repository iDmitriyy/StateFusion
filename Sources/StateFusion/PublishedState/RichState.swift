//
//  StateAndData.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

// MARK: - StateAndData

/// A composite container that bundles a finite state machine (`state`) with its associated extended data (`data`).
///
/// This structure provides a data snapshot that can be used for both direct imperative reads
/// and emission through reactive streams. Carrying the `lastWrite` property allows downstream code
/// to instantly know how this snapshot was produced without needing to compare new values against previous ones.
///
/// ### UML Mapping
/// - **EnumerableState**: Represents the discrete, enumerable **State**  of finite State Machine.
/// - **DataState**: Represents the **Extended State** (additional data that affects or accompanies transitions).
/// - **RichState**: Represents the **Composite State** or **State Compound**.
public struct StateCompound<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable {
  /// The current discrete state machine component.
  /// To modify this value, use the appropriate `accessHandle`.
  public fileprivate(set) var state: EnumerableState

  /// The extended contextual data associated with the state.
  /// To modify this value, use the appropriate `accessHandle`.
  public fileprivate(set) var data: DataState

  /// A marker indicating which specific write operation generated this state snapshot.
  ///
  /// Allows reactive stream subscribers and components to instantly see which property
  /// (`state` or `data`) was mutated, without needing to compare the new snapshot against the previous one.
  ///
  /// - Note: This tracks the execution path of the write call. If a property is overwritten with the exact same
  /// value (e.g., `data.text = data.text`), it is still recorded as a `.data` write operation, no matter
  /// if the data effectively stayed the same.
  public fileprivate(set) var lastWrite: StateCompoundWriteOperation

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

extension StateCompound: Copyable where EnumerableState: Copyable, DataState: Copyable {}

extension StateCompound: Sendable where EnumerableState: Sendable, DataState: Sendable {}

extension StateCompound: Equatable where EnumerableState: Equatable, DataState: Equatable {}

/// Specifies which property was accessed during the write operation that produced this `RichState`.
public enum StateCompoundWriteOperation: Equatable, Sendable {
  /// The state compound was created for the first time via the initializer.
  case initial

  /// The write operation was performed exclusively on the `state` property.
  case state

  /// The write operation was performed exclusively on the `data` property.
  case data

  /// Both `state` and `data` properties were updated together within a single write transaction.
  case combined
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - AccessHandle

public struct StateCompoundAccessHandle<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable, ~Escapable {
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
  /* private */ internal var _mutableRef: _MutableRef<StateCompound<EnumerableState, DataState>>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming _MutableRef<StateCompound<EnumerableState, DataState>>) {
    _mutableRef = mutableRef
  }

  @usableFromInline
  internal consuming func finalizeAccess() -> StateCompoundWriteOperation? {
    let writeOperation: StateCompoundWriteOperation? = switch (isEnumerableStateMutablyAccessed, isDataStateMutablyAccessed) {
    case (false, false): nil
    case (true, false): .state
    case (false, true): .data
    case (true, true): .combined
    }

    if let writeOperation {
      _mutableRef.value.lastWrite = writeOperation
    }

    return writeOperation
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension StateCompoundAccessHandle: Sendable {}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Data Property AccessHandle

public struct StateCompoundDataPropertyAccessHandle<EnumerableState: ~Copyable, DataState: ~Copyable>: ~Copyable, ~Escapable {
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
  /* private */ internal var _mutableRef: _MutableRef<StateCompound<EnumerableState, DataState>>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming _MutableRef<StateCompound<EnumerableState, DataState>>) {
    _mutableRef = mutableRef
  }

  internal consuming func finalizeAccess() -> StateCompoundWriteOperation? {
    let writeOperation: StateCompoundWriteOperation? = _isDataStateMutablyAccessed ? .data : nil

    if let writeOperation {
      _mutableRef.value.lastWrite = writeOperation
    }

    return writeOperation
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension StateCompoundDataPropertyAccessHandle: Sendable {}
