//
//  _PublishedState.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 16.07.2026.
//

public import Combine
public import class Foundation.NSRecursiveLock

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - PublishedState Imp

@usableFromInline
internal final class _PublishedState<StateEntity: Sendable>: @unchecked Sendable {
//  private weak var _shared_publisher: InfallibleValuePublisher<StateEntity>?

  @usableFromInline
  /* private */ internal let _private_use_only_subject: CurrentValueSubject<StateEntity, Never>

  @usableFromInline
  /* private */ internal let _lock = NSRecursiveLock()

  /*fileprivate*/ internal init(_ initialValue: StateEntity) {
    _private_use_only_subject = CurrentValueSubject(initialValue)

    // TODO: - `publisher` subscriptions can retain underlying _subject. This should be tracked and logged as a warning
    // that once `~Copyable PublishedState` shell deinited, the subject also
    // deallocates (and _PublishedState instance as well).
//    publisher = _subject.eraseToAnyPublisher()
  }

  /*fileprivate*/ internal final func finishPublisher() { // TODO: - need better name
    _lock.lock(); defer { _lock.unlock() }
    _private_use_only_subject.send(completion: .finished)
  }

  /*fileprivate*/ internal func publisher() -> InfallibleValuePublisher<StateEntity> {
//    _lock.lock(); defer { _lock.unlock() }

    let publisher: InfallibleValuePublisher<StateEntity>
//    if let _publisher = _shared_publisher {
//      publisher = _publisher
//    } else {
      publisher = InfallibleValuePublisher(retained_unverifiedValuePublisher: _private_use_only_subject)
//      _shared_publisher = publisher
//    }
    return publisher
  }

  // MARK: Synchronous Thread-Safe access

  @inlinable
  @inline(always)
  internal final func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }
    return try access(_private_use_only_subject.value)
  }

  /// Provides mutable access to the state, updating the stored state **only** when a mutation actually occurred.
  ///
  /// - Parameter access: A closure receiving an `inout AccessHandle`.
  /// - Returns: The value returned from `access` closure.
  ///
  /// ## Semantics
  /// - Inside `access` closure, read or write `.mutableState` freely.
  /// - After the closure returns, the published state is updated if
  ///   a write to `mutableState` happened inside the closure.
  /// - If no write occurred, the state remains unchanged and no
  ///   subscribers are notified.
  ///
  /// ## Why `AccessHandle` is `~Copyable`
  /// - Mutation tracking state is tied to a single closure invocation.
  /// - Copying the handle would break the one‑to‑one relationship
  ///   between mutation detection and state update.
  /// - `~Copyable` prevents the handle from crossing isolation regions
  ///   or being used after the closure ends, enforcing local, single‑owner usage.
  ///
  /// ## Rationale
  /// Encapsulating the mutable state together with its mutation‑tracking
  /// information in a non‑copyable container makes the write‑only‑if‑mutated
  /// semantics explicit and compiler‑checked, without exposing internal flags.
  @inlinable
  @inline(always)
  internal final func withLockMutableAccess<R>(_ access: (inout GenericStateAccessHandle<StateEntity>) -> sending R)
    -> sending R {
    _lock.lock(); defer { _lock.unlock() }

    var stateEntity = _private_use_only_subject.value
    var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&stateEntity))
    let result = access(&accessHandle)
    let isMutablyAccessed = accessHandle.isMutablyAccessed

    if isMutablyAccessed {
      _private_use_only_subject.value = stateEntity
    }

    return result
  }
}

extension _PublishedState {
  @inlinable
  @inline(always)
  internal final func withLockMutableAccessStateCompound<EnumerableState, DataState, R, E>(
    _ access: (inout StateCompoundAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == StateCompound<EnumerableState, DataState> {
    _lock.lock(); defer { _lock.unlock() }

    var stateCompound = _private_use_only_subject.value
    var accessHandle = StateCompoundAccessHandle(mutableRef: _MutableRef(&stateCompound))
    let result = try access(&accessHandle)
    let emissionReason = accessHandle.finalizeAccess()

    let isMutablyAccessed = emissionReason != nil
    if isMutablyAccessed {
      _private_use_only_subject.value = stateCompound
    }

    return result
  }

  internal final func withLockMutableAccessDataState<EnumerableState, DataState, R, E>(
    _ access: (inout StateCompoundDataPropertyAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == StateCompound<EnumerableState, DataState> {
    _lock.lock(); defer { _lock.unlock() }

    var stateCompound = _private_use_only_subject.value
    var accessHandle = StateCompoundDataPropertyAccessHandle(mutableRef: _MutableRef(&stateCompound))
    let result = try access(&accessHandle)
    let emissionReason = accessHandle.finalizeAccess()

    let isMutablyAccessed = emissionReason != nil
    if isMutablyAccessed {
      _private_use_only_subject.value = stateCompound
    }

    return result
  }
}

extension _PublishedState {
  public func enumerableStatePublisher<EnumerableState, DataState>() -> InfallibleValuePublisher<EnumerableState>
    where StateEntity == StateCompound<EnumerableState, DataState> {
    fatalError()
  }

  // FIXME: - implement
  public func dataStatePublisher<EnumerableState, DataState>() -> InfallibleValuePublisher<DataState>
    where StateEntity == StateCompound<EnumerableState, DataState> {
    fatalError()
  }
}
