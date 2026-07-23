//
//  CancellationBag.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine
import os
// private import struct OrderedCollections.OrderedSet

/// A thread-safe container of Combine cancellables
/// that cancels added cancellables on `deinit`.
///
/// Use `CancellationBag` when you need:
/// - Deterministic cancellation on scope end
/// - Explicit lifecycle boundaries
/// - Thread-safe insertion and disposal
///
/// Implementation is based on:
/// https://github.com/ReactiveX/RxSwift/blob/5004a18539bd68905c5939aa893075f578f4f03d/RxSwift/Disposables/DisposeBag.swift
///
/// ## Example
///
/// ```swift
/// let bag = CancellationBag()
///
/// publisher
///     .sink { print($0) }
///     .store(in: bag)
///
/// ```
///
/// ## Comparison with `Set<AnyCancellable>`
///
/// | Feature                              |      `Set<AnyCancellable>`      | `CancellationBag` |
/// |:------------------------------:|:----------------------------------------:|:-------------------------:|
/// | Cancellation trigger           | ARC deinit of each AnyCancellable |  ARC deinit of bag        |
/// | Thread-safe                       | No                                                     | Yes                               |
/// | Reentrancy-safe                | No                                                     | Yes                               |
/// | Ordered / unique storage | N/A                                                    | Yes                               |
/// | Insert during disposal        | Undefined                                        | Cancel immediately     |
/// | RxSwift-style semantics    | No                                                    | Yes                               |
/// ¹ Insertions performed reentrantly during bag deinitialization are
///  cancelled immediately to avoid leaks.
///
/// ## Notes
/// - Cancellation always occurs outside internal locks to avoid reentrancy
///   and deadlocks.
/// - Intended for ViewModels, coordinators, and long-lived services.
/// - There is no public `cancel()` method; cancellation is performed by
///   releasing or replacing the bag.
///
/// ## Example: owner scope
///
/// ```swift
/// final class Owner {
///     let bag = CancellationBag()
///
///     init() {
///         publisher
///             .sink { print($0) }
///             .store(in: bag)
///     }
/// }
/// ```
///
/// ## Example: cancel all subscriptions
///
/// ### Using `Set<AnyCancellable>`
///
/// ```swift
/// final class Service {
///     private var cancellables = Set<AnyCancellable>()
///
///     func start() {
///         publisher
///             .sink { print($0) }
///             .store(in: &cancellables)
///     }
///
///     func stop() {
///         cancellables.removeAll()
///     }
/// }
/// ```
/// Removing all elements drops references, but cancellation occurs only
/// when ARC deallocates each `AnyCancellable`. The timing is not guaranteed.
/// **What you might want:**
/// - Subscriptions are cancelled immediately when stop() is called
/// **What actually happens:**
/// - removeAll() drops references
/// - Cancellation occurs only when ARC deallocates each AnyCancellable
/// - Deallocation timing:
///   - may be immediate
///   - may be deferred
///   - may never happen (if references exist elsewhere)
/// You cannot guarantee that cancellation happens at stop()
///
/// ### Using `CancellationBag`
///
/// ```swift
/// final class Service {
///     private var bag = CancellationBag()
///
///     func start() {
///         publisher
///             .sink { print($0) }
///             .store(in: bag)
///     }
///
///     func stop() {
///         bag = CancellationBag() // deinitializes old bag
///     }
/// }
/// ```
/// Replacing the bag deterministically cancels all stored subscriptions
/// exactly once, on the calling thread, while the service itself remains alive.
/// **What you get:**
/// - destroying of old bag calls `cancel()` immediately
/// - Happens on the calling thread
/// - Happens exactly once
/// - Service remains alive
/// - New subscriptions after `dispose()` are cancelled immediately
///   (via reentrancy or races during deinit).
@_staticExclusiveOnly
public struct CancellationBag: ~Copyable, Sendable {
  private let storage: OSAllocatedUnfairLock<Storage>

  public init() {
    storage = OSAllocatedUnfairLock(uncheckedState: Storage())
  }

  deinit {
    dispose()
  }

  private func dispose() {
    let oldDisposables = _dispose()

    for disposable in oldDisposables.cancellableObjects {
      disposable.cancel()
    }

    for disposable in oldDisposables.cancellableExistentials {
      disposable.cancel()
    }
  }

  private func _dispose() -> (cancellableObjects: OrderedSet<AnyCancellable>, cancellableExistentials: [any Cancellable]) {
    storage.withLockUnchecked { storage in
      let disposables = (storage.cancellableObjects, storage.cancellableExistentials)

      storage.cancellableObjects.removeAll()
      storage.cancellableExistentials.removeAll()
      storage.isDisposed = true

      return disposables
    }
  }

  // MARK: - Insert single Cancellable

  public func insert(_ cancellableObject: AnyCancellable) {
    _insert(object: cancellableObject)?.cancel() // Cancel outside the lock to prevent reentrancy
  }

  private func _insert(object: AnyCancellable) -> AnyCancellable? {
    storage.withLockUnchecked { storage in
      if storage.isDisposed {
        return object
      } else {
        storage.cancellableObjects.append(object)
        return nil
      }
    }
  }

  public func insert(_ cancellable: any Cancellable) {
    if let cancellableObject = cancellable as? AnyCancellable {
      insert(cancellableObject)
    } else {
      _insert(existential: cancellable)?.cancel() // Cancel outside the lock to prevent reentrancy
    }
  }

  private func _insert(existential: any Cancellable) -> (any Cancellable)? {
    storage.withLockUnchecked { storage in
      if storage.isDisposed {
        return existential
      } else {
        storage.cancellableExistentials.append(existential)
        return nil
      }
    }
  }

  // MARK: - Insert multiple Cancellables

  public func insert<C: Collection>(_ anyCancellableObjects: C) where C.Element == AnyCancellable {
    let toCancel = storage.withLockUnchecked { storage -> C? in
      if storage.isDisposed {
        return anyCancellableObjects
      } else {
        storage.cancellableObjects.append(contentsOf: anyCancellableObjects)
        return nil
      }
    }

    // Cancel outside the lock to prevent reentrancy
    toCancel?.forEach { $0.cancel() }
  }

  public func insert(_ cancellables: some Collection<any Cancellable>) {
    var cancellableObjects: [AnyCancellable] = []
    var cancellableExistentials: [any Cancellable] = []

    // Split AnyCancellable vs other existentials
    for cancellable in cancellables {
      if let anyCancellableObject = cancellable as? AnyCancellable {
        cancellableObjects.append(anyCancellableObject)
      } else {
        cancellableExistentials.append(cancellable)
      }
    }

    let toCancelExistentials = storage.withLockUnchecked { storage -> [any Cancellable]? in
      if storage.isDisposed {
        return cancellableExistentials
      } else {
        storage.cancellableExistentials += cancellableExistentials
        return nil
      }
    }
    // Cancel outside the lock to prevent reentrancy
    toCancelExistentials?.forEach { $0.cancel() }

    if !cancellableObjects.isEmpty {
      insert(cancellableObjects) // re-use the previous function
    }
  }

  // TODO: ?make Storage ~Copyable.
  // Also deinit does not need withLock – we can access data directly. But if Storage is moveOnly, then
  // it is needed to be extracted from Mutex. Mutex need to be consumed in deinit which is not possible yet.
  // https://forums.swift.org/t/pitch-2-allowing-for-partial-mutation-and-consumption-inside-of-non-copyable-type-deinit/88437/3
  private struct Storage {
    var cancellableObjects: OrderedSet<AnyCancellable> = []
    var cancellableExistentials: [any Cancellable] = []

    var isDisposed: Bool = false
  }
}

extension CancellationBag {
  /// Convenience function allows a list of cancellables to be gathered for disposal.
  public func insert(_ disposables: AnyCancellable...) {
    insert(disposables)
  }

  /// Convenience function allows a list of cancellables to be gathered for disposal.
  public func insert(@DisposableBuilder builder: () -> [AnyCancellable]) {
    insert(builder())
  }

  /// A function builder accepting a list of cancellables and returning them as an array.
  @resultBuilder
  public enum DisposableBuilder {
    public static func buildBlock(_ disposables: AnyCancellable...) -> [AnyCancellable] {
      disposables
    }
  }
}

// MARK: - AnyCancellable + Bag

extension AnyCancellable {
  public final func store(in bag: borrowing CancellationBag) {
    bag.insert(self)
  }
}

extension Cancellable {
  public func store(in bag: borrowing CancellationBag) {
    bag.insert(self)
  }
}

// ----

// TODO: Remove it when OrderedSet from Swift-Collections become part of standard library
fileprivate typealias OrderedSet<Element> = Array<Element>
