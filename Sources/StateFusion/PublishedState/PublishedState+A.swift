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
