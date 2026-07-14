//
//  InsulatedValueRelay.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 18.06.2026.
//

//public import Combine

//public final class InsulatedValueRelay<Output>: Subject<Output, Never> { // | Insulated Transactional
//  internal let _subject: CurrentValueSubject<SequentialSnapshot<Output>, Never>
//  private let _version: RecursiveLock<UInt32>
//
//  public final var valueSnapshot: SequentialSnapshot<Output> {
//    _subject.value
//  }
//
//  public final var value: Output {
//    _subject.value.value
//  }
//
//  public init(_ value: Output) {
//    let initial = SequentialSnapshot(initial: value)
//    _version = RecursiveLock(initial._version)
//    _subject = CurrentValueSubject(initial)
//  }
//
//  // Publisher Protocol Imp:
//
//  public final func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
//    _subject
//      .map { snapshot in snapshot.value }
//      .receive(subscriber: subscriber)
//  }
//
//  // Subject Protocol Imp:
//
//  public final func send(_ value: Output) {
//    _version.withLock { current in
//      current += 1
//      _subject.send(SequentialSnapshot(value: value, version: current))
//    }
//  }
//
//  public final func send(completion: Subscribers.Completion<Failure>) {
//    _subject.send(completion: completion)
//  }
//
//  public final func send(subscription: any Subscription) {
//    _subject.send(subscription: subscription)
//  }
//}
//
//extension InsulatedValueRelay {
//  public final func valuePublisher() -> InfallibleValuePublisher<Output> {
//    fatalError()
//  }
//
//  public final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Output>) -> AnyPublisher<Output, Never> {
//    _subject
//      .drop(while: { [referenceVersion = snapshot._version] in
//        $0._version <= referenceVersion
//      })
//      .map { $0.value }
//      .eraseToAnyPublisher()
//    // FIXME: + share
//  }
//}


/*
 /// `CurrentValueMutualRelay` is a thread-safe reactive state container
 /// built specifically for screens using Unidirectional Data Flow (UDF) and State Machines.
 ///
 /// ### Problems Solved:
 /// 1. **Data Races Without Async Code:** Allows you to safely mutate state from any thread
 ///    synchronously (right here, right now). It eliminates the need for `DispatchQueue` jumping
 ///    or async/await Actors, which introduce asynchronous delays to UI rendering.
 /// 2. **Hanging Memory on Screen Dismissal:** When a user leaves a screen, active asynchronous
 ///    `for await` loops often hang in memory forever. This primitive automatically triggers a
 ///    `.finished` signal upon destruction, tearing down downstream pipelines and preventing silent memory leaks.
 /// 3. **Accidental UI Breaks:** Guarantees that the stream will never fail with an error
 ///    (`Failure == Never`). External network crashes or side-effect failures cannot accidentally kill the UI subscription.
 ///
 /// ### Core Principles:
 /// * **Safe In-Place Mutation:** Through the `withLockMutableAccess` function, you gain direct,
 ///   lock-protected access to the state. Code inside this block executes instantly and atomically.
 /// * **Automatic Completion:** The moment the state object leaves memory (`deinit`), it automatically
 ///   notifies all subscribers that it is `.finished`. No manual clean-up or cancellation tracking is required.
 /// * **Strict Chronological Timeline:** Every single state change is recorded sequentially. This ensures
 ///   the UI never renders an older state on top of a newer one due to multi-threaded race conditions.

 */

/*
 Thank you for the correction. Let me re-understand the architecture.

 ## Corrected Taxonomy
 | Type                      |Values|Errors|Completion (user)|Completion (deinit)|withLockMutableAccess|
 | ------------------------- |:----:|:----:|:---------------:|:-----------------:|:-------------------:|
 | `CurrentValueSubject`     |  ✅  |  ✅  |        ✅       |         ❌        |         ❌          |
 | `CurrentValueRelay`       |  ✅  |  ❌  |        ❌       |         ❌        |         ❌          |
 | New Subject-like          |  ✅  |  ❌  |        ✅       |         ❌        |         ✅          |
 | `InsulatedValueRelay`     |  ✅  |  ❌  |        ❌       |         ✅        |         ✅          |

 | InsulatedRelay TransactionalRelay ExclusiveRelay MutualRelay IsolatedRelay

 | withExclusiveAccess withIsolatedAccess mutate {}

 ## Clarifying questions

 1. Does `PublishedState` keep its name, or should it also be renamed to `CurrentValue` + word?
 2. The two new types — are they both copyable classes (like current `InfallibleValueSubject`), or is the Relay-like one non-copyable (like `PublishedState`)?
 3. For the Subject-like type: it can send completion, but deinit does NOT send completion. For the Relay-like type: user cannot send completion, but deinit DOES send `.finished`. Is this correct?

 ## Naming candidates

 Given the constraint `CurrentValue` + single word consistent with Subject/Relay:

 **Subject-like** (can complete, no deinit completion):
 - `CurrentValueSource` — a source of values that can end
 - `CurrentValueEmitter` — emits values, can complete
 - `CurrentValueFlow` — a flow of values, can end

 **Relay-like** (no user completion, deinit sends .finished):
 - `CurrentValueStore` — stores values, lifecycle-bound
 - `CurrentValueCache` — caches current value, auto-clears on dealloc
 - `CurrentValueHolder` — holds a value, lifecycle-bound

 Do these directions make sense, or do you have a different mental model for the naming?

 */

// onComplete in deinit
/*
 Yes, it is incredibly useful.
 It acts as a safety release valve for asynchronous downstream chains. It solves three critical problems:

 Problem A: Unending for await Loops (Swift Concurrency)When bridging a Combine publisher to modern Swift Concurrency using .values, it generates an infinite AsyncSequence.

 Without completion in deinit: If PublishedState deallocates silently, the for await loop hangs forever in an await state. The enclosing Task is leaked, and memory goes up.With completion in deinit: Emitting .finished causes the AsyncSequence iterator to naturally return nil. The for await loop safely terminates, and the Task cleans itself up.

 Problem B: State Accumulation Operators (.collect(), .reduce())Operators that gather values over time require a termination signal to deliver their payload.The Problem: If you run statePublisher.collect(), it accumulates updates but will never emit anything downstream until it receives a terminal .finished event.The Solution: Auto-completing on deinit lets downstream architectures catch the complete sequence history exactly when the state machine dies.

 Problem C: Deterministic Memory Management (.sink)Standard .sink subscriptions are usually stored in an external Set<AnyCancellable>.The Problem: If a subscriber forgets to cancel their token, but the underlying state manager object dies, the subscriber's closure is kept alive by the remaining pipeline infrastructure.The Solution: Sending .finished on deinit tears down the subscription graph from the top down. The subscriber gets notified that the source is dead, automatically invalidating the pipeline.
 */
