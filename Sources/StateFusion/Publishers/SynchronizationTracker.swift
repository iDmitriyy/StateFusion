//
//  SynchronizationTracker.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.06.2026.
//

import Foundation

extension NSRecursiveLock {
  @inline(always)
  final func performLocked<T>(_ action: () -> T) -> T {
    lock(); defer { self.unlock() }
    return action()
  }
}

#if DEBUG
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
