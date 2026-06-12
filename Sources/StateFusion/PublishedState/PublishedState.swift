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
  public var publisher: ValuePublisher<StateEntity> {
    _stateImpObject.publisher
  }

  @usableFromInline
  internal let _stateImpObject: _PublishedState<StateEntity>

  public init(_ initialValue: consuming StateEntity) {
    _stateImpObject = _PublishedState(initialValue)
  }

  public init<EnumerableState, DataState>(enumerableState: consuming EnumerableState, dataState: consuming DataState)
    where StateEntity == RichState<EnumerableState, DataState> {
    _stateImpObject = _PublishedState(RichState(state: enumerableState, data: dataState))
  }

  // TODO: - add bag

  deinit {
    _stateImpObject.finishPublisher()
  }

  // MARK: Synchronous Thread-Safe access

  @inlinable
  @inline(always)
  public func withLockAccess<R, E>(_ access: (borrowing StateEntity) throws(E) -> sending R)
    throws(E) -> sending R {
    try _stateImpObject.withLockAccess(access)
  }

  /// For mutating `RichState` use withLockMutableAccessRichState
  @inlinable
  @inline(always)
  public func withLockMutableAccess<R>(_ access: (inout GenericStateAccessHandle<StateEntity>) -> sending R)
    -> sending R {
    _stateImpObject.withLockMutableAccess(access)
  }

  @inlinable
  @inline(always)
  public func withLockMutableAccessRichState<EnumerableState, DataState, R, E>(
    _ access: (inout RichStateAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == RichState<EnumerableState, DataState> {
    try _stateImpObject.withLockMutableAccessRichState(access)
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
  internal let publisher: ValuePublisher<StateEntity>

  @usableFromInline
  /* private */ internal let _subject: CurrentValueSubject<StateEntity, Never>

  @usableFromInline
  /* private */ internal let _lock = NSRecursiveLock()

  fileprivate init(_ initialValue: StateEntity) {
    _subject = CurrentValueSubject(initialValue)
    publisher = _subject.eraseToAnyPublisher()
  }

  fileprivate final func finishPublisher() {
    _subject.send(completion: .finished)
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
  internal final func withLockMutableAccessRichState<EnumerableState, DataState, R, E>(
    _ access: (inout RichStateAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == RichState<EnumerableState, DataState> {
    _lock.lock(); defer { _lock.unlock() }

    var richState = _subject.value
    var accessHandle = RichStateAccessHandle(mutableRef: _MutableRef(&richState))
    let result = try access(&accessHandle)
    let emissionReason = accessHandle.finalizeAccess()

    let isMutablyAccessed = emissionReason != nil
    if isMutablyAccessed {
      _subject.value = richState
    }
      
    return result
  }

  internal final func withLockMutableAccessDataState<EnumerableState, DataState, R, E>(
    _ access: (inout RichStateDataPropertyAccessHandle<EnumerableState, DataState>) throws(E) -> sending R,
  ) throws(E) -> sending R
    where StateEntity == RichState<EnumerableState, DataState> {
    _lock.lock(); defer { _lock.unlock() }

      var richState = _subject.value
      var accessHandle = RichStateDataPropertyAccessHandle(mutableRef: _MutableRef(&richState))
      let result = try access(&accessHandle)
      let emissionReason = accessHandle.finalizeAccess()

      let isMutablyAccessed = emissionReason != nil
      if isMutablyAccessed {
        _subject.value = richState
      }
        
      return result
  }
}

extension _PublishedState {
  public func enumerableStatePublisher<EnumerableState, DataState>() -> ValuePublisher<EnumerableState>
    where StateEntity == RichState<EnumerableState, DataState> {
    fatalError()
  }

  // FIXME: - implement
  public func dataStatePublisher<EnumerableState, DataState>() -> ValuePublisher<DataState>
    where StateEntity == RichState<EnumerableState, DataState> {
    fatalError()
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - Imperative Event Handling Funcs

extension PublishedState {
  public func onEventReduce<R>(_ reduceState: (_ state: borrowing StateEntity) -> EventOutcome<StateEntity, R>,
                               do action: (R) -> Void) {
    if let reductionOutput = withLock_onEvenReduce(reduceState) {
      action(reductionOutput)
    }
  }

  public func onEventReduce<R>(_ reduceState: (_ state: borrowing StateEntity) -> EventOutcome<StateEntity, R>) -> R? {
    withLock_onEvenReduce(reduceState)
  }

  public func onEventReduce(_ reduceState: (_ state: borrowing StateEntity) -> EventOutcome<StateEntity, Void>) {
    withLock_onEvenReduce(reduceState)
  }

  private func withLock_onEvenReduce<R>(_ reduceState: (_ state: borrowing StateEntity) -> EventOutcome<StateEntity, R>) -> R? {
    withLockMutableAccess {
      let eventOutcome = reduceState($0.stateEntity)
      switch eventOutcome {
      case let .transition(newState, oldStateAssociatedValue):
        $0.stateEntity = newState
        return oldStateAssociatedValue

      case let .handled(oldStateAssociatedValue):
        return oldStateAssociatedValue

      case .ignore:
        return nil
      }
    }
  }

  // -------

  // FIXME: state.handle { | state.read { – сделать невоpможным обращение к state внутри access замыкания
  // Если пользователь случайно сделает I/O внутри handle { }, lock будет заблокирован на всё время I/O.

  public func read<R>(_ closure: (borrowing StateEntity) -> sending R) -> sending R {
    withLockAccess(closure)
  }

  /*
   Ok. How good is my solution dealing with race conditions compared to flux / redux / TCA, and particulary for side effects

   ## Рекомендации по улучшению thread safety

   1. **Добавить `nonrecursive` lock вместо RecursiveLock** или опцию. Reentrancy почти всегда баг, а не intentional design. Если нужен read during mutation — вынести read до handle.

   2. **Документировать contract:** closure в `handle { }` MUST be synchronous and fast. Не делать I/O, не вызывать async.

   3. **Для критических сквозных операций (state change + side effect атомарно)** можно добавить `handle(scheduling:)`:
   ```swift
   state.handle(scheduling: .async) { state in
       // state evaluated under lock, but no I/O here
       return .transition(to: .loaded)
   } do: { output in
       await network.load() // side effect — async, not under lock
   }
   ```

   4. **Глобальная проблема ordering** не решается без центрального serial executor. Для RIBs это допустимо — каждый RIB имеет свой `PublishedState`, cross-RIB коммуникация через router.

   Но базовый вопрос: **насколько критична thread-safety для RIBs + UDF сценариев?** Обычно UI-события на MainActor, а network callbacks приходят на serial queue или MainActor. На практике race condition редки. Реальная сложность — reentrancy и случайный I/O под lock.
   */
}
