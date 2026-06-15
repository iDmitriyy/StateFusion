//
//  InfallibleValueSubject.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 15.06.2026.
//

public import Combine

/// Owned
public struct OwnedInfallibleValueSubject<Output>: ~Copyable {}

//

public final class InfallibleValueSubject<Output>: Subject<Output, Never> {
  internal let _subject: CurrentValueSubject<SequentialSnapshot<Output>, Never>
  private let _serialNumber: RecursiveLock<UInt64>

  public final var valueSnapshot: SequentialSnapshot<Output> {
    _subject.value
  }

  public final var value: Output {
    _subject.value.value
  }

  // https://github.com/ReactiveX/RxSwift/blob/132aea4f236ccadc51590b38af0357a331d51fa2/RxSwift/Rx.swift#L71

  public init(_ value: Output) {
    let initial = SequentialSnapshot(initial: value)
    _serialNumber = RecursiveLock(initial._version)
    _subject = CurrentValueSubject(initial)
  }

  // public final func versionedPublisher() -> AnyPublisher<SequentialSnapshot<Output>, Never> {
  //   _subject.eraseToAnyPublisher()
  // }

  // Publisher Protocol Imp:

  public final func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Output {
    _subject
      .map { snapshot in snapshot.value }
      .receive(subscriber: subscriber)
  }

  // Subject Protocol Imp:

  public final func send(_ value: Output) {
    _serialNumber.withLock { current in
      current += 1
      _subject.send(SequentialSnapshot(value: value, serialNumber: current))
    }
  }

  public final func send(completion: Subscribers.Completion<Failure>) {
    _subject.send(completion: completion)
  }

  public final func send(subscription: any Subscription) {
    _subject.send(subscription: subscription)
  }
}

extension InfallibleValueSubject {
  public final func takeUpdates(afterSnapshot snapshot: SequentialSnapshot<Output>) -> AnyPublisher<Output, Never> {
    _subject.drop(while: { [referenceVersion = snapshot._version] in
      $0._version <= referenceVersion
    })
    .map { $0.value }
    .eraseToAnyPublisher()
  }
}

#if DEBUG
  import Foundation

  final class SynchronizationTracker {
    // https://github.com/ReactiveX/RxSwift/blob/132aea4f236ccadc51590b38af0357a331d51fa2/RxSwift/Rx.swift#L71
    
    private let lock = NSRecursiveLock()

    enum SynchronizationErrorMessages: String {
      case variable = "Two different threads are trying to assign the same `Variable.value` unsynchronized.\n    This is undefined behavior because the end result (variable value) is nondeterministic and depends on the \n    operating system thread scheduler. This will cause random behavior of your program.\n"
      
      case `default` = "Two different unsynchronized threads are trying to send some event simultaneously.\n    This is undefined behavior because the ordering of the effects caused by these events is nondeterministic and depends on the \n    operating system thread scheduler. This will result in a random behavior of your program.\n"
    }

    private var threads = [UnsafeMutableRawPointer: Int]()

    private func synchronizationError(_ message: String) {
      #if FATAL_SYNCHRONIZATION
        rxFatalError(message)
      #else
        print(message)
      #endif
    }

    final func register(synchronizationErrorMessage: SynchronizationErrorMessages) {
      lock.lock(); defer { self.lock.unlock() }
      let pointer = Unmanaged.passUnretained(Thread.current).toOpaque()
      let count = (threads[pointer] ?? 0) + 1

      if count > 1 {
        synchronizationError(
          "⚠️ Reentrancy anomaly was detected.\n" +
            "  > Debugging: To debug this issue you can set a breakpoint in \(#file):\(#line) and observe the call stack.\n" +
            "  > Problem: This behavior is breaking the observable sequence grammar. `next (error | completed)?`\n" +
            "    This behavior breaks the grammar because there is overlapping between sequence events.\n" +
            "    Observable sequence is trying to send an event before sending of previous event has finished.\n" +
            "  > Interpretation: This could mean that there is some kind of unexpected cyclic dependency in your code,\n" +
            "    or that the system is not behaving in the expected way.\n" +
            "  > Remedy: If this is the expected behavior this message can be suppressed by adding `.observe(on:MainScheduler.asyncInstance)`\n" +
            "    or by enqueuing sequence events in some other way.\n",
        )
      }

      threads[pointer] = count

      if threads.count > 1 {
        synchronizationError(
          "⚠️ Synchronization anomaly was detected.\n" +
            "  > Debugging: To debug this issue you can set a breakpoint in \(#file):\(#line) and observe the call stack.\n" +
            "  > Problem: This behavior is breaking the observable sequence grammar. `next (error | completed)?`\n" +
            "    This behavior breaks the grammar because there is overlapping between sequence events.\n" +
            "    Observable sequence is trying to send an event before sending of previous event has finished.\n" +
            "  > Interpretation: " + synchronizationErrorMessage.rawValue +
            "  > Remedy: If this is the expected behavior this message can be suppressed by adding `.observe(on:MainScheduler.asyncInstance)`\n" +
            "    or by synchronizing sequence events in some other way.\n",
        )
      }
    }

    final func unregister() {
      lock.performLocked {
        let pointer = Unmanaged.passUnretained(Thread.current).toOpaque()
        self.threads[pointer] = (self.threads[pointer] ?? 1) - 1
        if self.threads[pointer] == 0 {
          self.threads[pointer] = nil
        }
      }
    }
  }

#endif

extension NSRecursiveLock {
  @inline(always)
  final func performLocked<T>(_ action: () -> T) -> T {
    lock(); defer { self.unlock() }
    return action()
  }
}
