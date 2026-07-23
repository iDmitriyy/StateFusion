//
//  PublishedState+A.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 14.06.2026.
//

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
    withLockEmittingOnMutableAccess {
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

  // FIXME: state.handle { | state.read { — make it impossible to access state inside the access closure
  // If a user accidentally does I/O inside handle { }, the lock stays held for the entire I/O duration.

//  public func read<R>(_ closure: (borrowing GenericStateAccessHandle<StateEntity>) -> sending R) -> sending R {
//    withLockAccess(closure)
//  }

  /*
   Ok. How good is my solution dealing with race conditions compared to flux / redux / TCA, and particulary for side effects

   ## Thread Safety Recommendations

   1. **Use a `nonrecursive` lock instead of RecursiveLock** (or offer both). Reentrancy is almost always a bug, not intentional design. If you need read-during-mutation, move the read before handle.

   2. **Document the contract:** the closure in `handle { }` MUST be synchronous and fast. No I/O, no async calls.

   3. **For critical atomic operations (state change + side effect together)**, add `handle(scheduling:)`:
   ```swift
   state.handle(scheduling: .async) { state in
       // state evaluated under lock, but no I/O here
       return .transition(to: .loaded)
   } do: { output in
       await network.load() // side effect — async, not under lock
   }
   ```

   4. **The global ordering problem** cannot be solved without a central serial executor. For RIBs this is acceptable — each RIB has its own `PublishedState`, cross-RIB communication goes through the router.

   But the core question is: **how critical is thread-safety for RIBs + UDF scenarios?** Usually UI events are on MainActor, and network callbacks come on a serial queue or MainActor. In practice, race conditions are rare. The real challenge is reentrancy and accidental I/O under lock.
   */
}
