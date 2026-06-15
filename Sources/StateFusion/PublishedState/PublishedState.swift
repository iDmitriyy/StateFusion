//
//  PublishedState.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 30.05.2026.
//

public import Combine
public import class Foundation.NSRecursiveLock

/// A thread‑safe, non‑copyable reactive state container.
///
/// `PublishedState` is the **single source of truth** for a piece of mutable state. It provides:
///
/// - **Reactive state‑machine** support via `filter(reducing:)` operators.
/// - **Imperative state‑machine** support via `onEventReduce`.
/// - **Reactive observation** through a `publisher` (backed by a `CurrentValueSubject`).
/// - **Atomic read‑modify‑write** via `withLockMutableAccess(_:)`, preventing data races under
///   concurrent mutation.
///
/// ## Why `~Copyable` struct instead of a class?
///
/// `PublishedState` wraps an internal class in a **non‑copyable struct**.
/// This is a deliberate choice over using a bare class:
///
/// 1. **Ownership enforcement** – Classes can be referenced from multiple places
///    simultaneously, making it impossible to know who owns the state. The non‑copyable
///    struct can only be held by a single variable, making the owner explicit and unique.
///
/// 2. **Accidental sharing prevention** – If the struct were copyable, a `let copy = state`
///    would create a second handle to the same storage.
///
/// 3. **Lifetime clarity** – Classes can be retained in closures and live longer than their
///    logical owner. The non‑copyable struct cannot be captured by escaping closures;
///    instead, the internal class reference is captured explicitly where needed (e.g., in
///    `filter(reducing:)` implementation). That capture is visible and intentional.
///
/// 4. **Safe borrowing** – To let other parts of the system read or mutate the state, the
///    owner passes the state as `borrowing`, giving temporary access without
///    transferring ownership. The compiler guarantees the owner outlives the borrowing
///    scope, eliminating use‑after‑free risks.
///
/// Under the hood, the struct holds a single strong reference to an internal class that
/// contains the actual `CurrentValueSubject` and lock. Because that class is a reference
/// type, it can be captured safely in Combine closures. The struct merely acts as a
/// unique, non‑copyable handle to that shared storage.

/// A thread‑safe, non‑copyable reactive state container.
///
/// `PublishedState` serves as the exclusive **single source of truth** for a mutable state.
/// It encapsulates an internal reference storage inside a non-copyable interface, forcing strict ownership boundaries
/// while providing concurrent atomicity and reactive projections.
///
/// ## Design & Semantics (`~Copyable`)
///
/// 1. **Ownership Enforcement:** Unlike bare classes with implicit shared ownership, this handle cannot
///    be duplicated. It restricts structural lifespan governance to a single unique variable.
/// 2. **Accidental Sharing Prevention:** Disables implicit handle copying (`let copy = state`). This ensures
///    mutations cannot fork or desynchronize across separate references.
/// 3. **Lifetime Clarity:** Prevents state from escaping through closures. While the handle itself
///    cannot be captured by escaping blocks, its underlying storage class reference is extracted explicitly
///    where needed (e.g., inside operators), making captures visible and intentional.
/// 4. **Safe Borrowing:** Read/write downstream scopes accept the state as `borrowing`. The compiler
///    statically guarantees that the owner outlives the borrowed scope, eliminating use-after-free conditions.
/// 5. **Automated Pipeline Collapse:** On handle `deinit`, a cleanup hook automatically finishes the reactive
///    subject. This forces downstream Combine chains to immediately emit `.finished`, tearing down dead subscriptions.
///
/// ## Underlying Mechanism
/// The struct holds a unique strong reference to an internal class containing a `CurrentValueSubject`
/// and lock. The struct acts as a unique, non-copyable semantic gatekeeper to this shared storage.
public struct PublishedState<StateEntity: Sendable>: ~Copyable, Sendable {
  @usableFromInline
  internal let _stateImpObject: _PublishedState<StateEntity>

  public init(_ initial: consuming StateEntity) {
    _stateImpObject = _PublishedState(initial)
  }

  // TODO: - add bag

  deinit {
    _stateImpObject.finishPublisher()
  }

  public func publisher() -> CurrentValuePublisher<StateEntity> {
    _stateImpObject.publisher()
  }

  // MARK: Synchronous Thread-Safe access

  @inlinable
  @inline(always)
  public func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccess(access)
  }

  /// For mutating `StateCompound` use withLockMutableAccessStateCompound
  @inlinable
  @inline(always)
  public func withLockMutableAccess<R>(_ access: (inout GenericStateAccessHandle<StateEntity>) -> sending R)
    -> sending R {
    _stateImpObject.withLockMutableAccess(access)
  }

  @inlinable
  @inline(always)
  public func withLockMutableAccessStateCompound<EnumerableState, DataState, R, E>(
    _ access: (inout StateCompoundAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == StateCompound<EnumerableState, DataState> {
    try _stateImpObject.withLockMutableAccessStateCompound(access)
  }
}

extension PublishedState {
  public init<EnumerableState, DataState>(enumerableState: consuming EnumerableState, dataState: consuming DataState)
    where StateEntity == StateCompound<EnumerableState, DataState> {
    self.init(StateCompound(state: enumerableState, data: dataState))
  }
}

extension PublishedState where StateEntity: AnyObject {
  @available(*, unavailable, message: "Not supported") // TODO: - implement
  public init(_: consuming sending StateEntity) {
    // immutable data-classes might be supported.
    // However, Sendable class instances are typically mutable using Locks, and populating them via Publisher is meaningless.
    fatalError()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - PublishedState Imp

@usableFromInline
internal final class _PublishedState<StateEntity: Sendable>: @unchecked Sendable {
  private weak var _shared_publisher: CurrentValuePublisher<StateEntity>? // FIXME: - is it safe and no retain cycle?

  @usableFromInline
  /* private */ internal let _subject: CurrentValueSubject<StateEntity, Never>

  @usableFromInline
  /* private */ internal let _lock = NSRecursiveLock()

  fileprivate init(_ initialValue: StateEntity) {
    _subject = CurrentValueSubject(initialValue)

    // TODO: - `publisher` subscriptions can retain underlying _subject. This should be tracked and logged as a warning
    // that once `~Copyable PublishedState` shell deinited, the subject also
    // deallocates (and _PublishedState instance as well).
//    publisher = _subject.eraseToAnyPublisher()
  }

  fileprivate final func finishPublisher() { // TODO: - need better name
    _lock.lock(); defer { _lock.unlock() }
    _subject.send(completion: .finished)
  }

  fileprivate func publisher() -> CurrentValuePublisher<StateEntity> {
    _lock.lock(); defer { _lock.unlock() }

    let publisher: CurrentValuePublisher<StateEntity>
    if let _publisher = _shared_publisher {
      publisher = _publisher
    } else {
      publisher = CurrentValuePublisher(retained_unverifiedValuePublisher: _subject, getCurrentValue: { [publishedState = self] in
        publishedState.withLockAccess { stateEntity in stateEntity }
      })
      _shared_publisher = publisher
    }
    return publisher
  }

  // MARK: Synchronous Thread-Safe access

  @inlinable
  @inline(always)
  internal final func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    _lock.lock(); defer { _lock.unlock() }
    return try access(_subject.value)
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

    var stateEntity = _subject.value
    var accessHandle = GenericStateAccessHandle(mutableRef: _MutableRef(&stateEntity))
    let result = access(&accessHandle)
    let isMutablyAccessed = accessHandle.isMutablyAccessed

    if isMutablyAccessed {
      _subject.value = stateEntity
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

    var stateCompound = _subject.value
    var accessHandle = StateCompoundAccessHandle(mutableRef: _MutableRef(&stateCompound))
    let result = try access(&accessHandle)
    let emissionReason = accessHandle.finalizeAccess()

    let isMutablyAccessed = emissionReason != nil
    if isMutablyAccessed {
      _subject.value = stateCompound
    }

    return result
  }

  internal final func withLockMutableAccessDataState<EnumerableState, DataState, R, E>(
    _ access: (inout StateCompoundDataPropertyAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == StateCompound<EnumerableState, DataState> {
    _lock.lock(); defer { _lock.unlock() }

    var stateCompound = _subject.value
    var accessHandle = StateCompoundDataPropertyAccessHandle(mutableRef: _MutableRef(&stateCompound))
    let result = try access(&accessHandle)
    let emissionReason = accessHandle.finalizeAccess()

    let isMutablyAccessed = emissionReason != nil
    if isMutablyAccessed {
      _subject.value = stateCompound
    }

    return result
  }
}

extension _PublishedState {
  public func enumerableStatePublisher<EnumerableState, DataState>() -> CurrentValuePublisher<EnumerableState>
    where StateEntity == StateCompound<EnumerableState, DataState> {
    fatalError()
  }

  // FIXME: - implement
  public func dataStatePublisher<EnumerableState, DataState>() -> CurrentValuePublisher<DataState>
    where StateEntity == StateCompound<EnumerableState, DataState> {
    fatalError()
  }
}
