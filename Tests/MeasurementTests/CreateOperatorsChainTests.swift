//
//  ValuePublisherOperatorsInit.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 17.07.2026.
//

public import Combine
import StateFusion
import Testing

/// See also: `ThroughputTests`
struct CreateOperatorsChainTests {
  let outer: Int = 150
  let inner: Int = 1000

  // MARK: - `Operators Chain Creation`
  
  /// Measures the performance overhead of creating a chain of Combine operators (e.g. .map)
  /// using three different approaches for a CurrentValuePublisher.
  /// It specifically bench-marks how the internal storage mechanism of each wrapper affects memory
  /// allocation and CPU time during type initialization.
  @Test func `Operators Chain Creation`() {
    let currentValueSubject = CurrentValueSubject<String, Never>("")

    let imp_current = CurrentValuePublisher(CurrentValueSubject<String, Never>("")) // Library actual implementation
    let imp_Closure = CurrentValuePublisher_Closure(CurrentValueSubject<String, Never>(""))
    let imp_Existential = CurrentValuePublisher_Existential(CurrentValueSubject<String, Never>(""))
    let imp_Any = CurrentValuePublisher_Any(CurrentValueSubject<String, Never>(""))
    
    // TODO: - other CurrentValuePublisher imps
    
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outer) { // reference measurement
      for _ in 0..<inner {
        blackHole(currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tCurrentValueSubjectErased) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.eraseToAnyPublisher())
        // TODO: - is it correct to call .eraseToAnyPublisher() here
      }
    }

    let (_, tImp_current) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_current.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tImp_Closure) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_Closure.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }
    // FIXME: - write difference from map2
    // this variant eliminate nesting in chain "CurrentValuePublisher-Base1-CurrentValuePublisher-Base2..."
    let (_, tImp_Existential_1) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_Existential.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tImp_Existential_2) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_Existential.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { "\($0)" })
      }
    }

    let (_, tImp_Any_1) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_Any.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" })
      }
    }

    let (_, tImp_Any_2) = performMeasuredAction(count: outer) {
      for _ in 0..<inner {
        blackHole(imp_Any.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { $0 }.map2 { "\($0)" })
      }
    }

    printTable("OperatorsChain Init per second",
               rows: [("CurrentValueSubject", tCurrentValueSubject),
                      ("CurrentValueSubjectErased", tCurrentValueSubjectErased),
                      ("imp_current", tImp_current),
                      ("imp_Closure", tImp_Closure),
                      ("imp_Existential 1", tImp_Existential_1),
                      ("imp_Existential 2", tImp_Existential_2),
                      ("imp_Any 1", tImp_Any_1),
                      ("imp_Any 2", tImp_Any_2)])
  }

  // MARK: - `Operators Chain Subscription`
  
  @Test func `Operators Chain Subscription`() {
    let outerLocal: Int = 10
    let total = outerLocal * inner

    let currentValueSubject = CurrentValueSubject<String, Never>("")
    let imp_current = CurrentValuePublisher(CurrentValueSubject<String, Never>(""))

    let imp_Existential = CurrentValuePublisher_Existential(retained_unverifiedValuePublisher: CurrentValueSubject<String, Never>(""))
    let imp_Closure = CurrentValuePublisher_Closure(retained_unverifiedValuePublisher: CurrentValueSubject<String, Never>(""))
    let imp_Pointer = CurrentValuePublisher_Pointer(retained_unverifiedValuePublisher: CurrentValueSubject<String, Never>(""))
    let imp_PointerInline = CurrentValuePublisher_Inline(retained_unverifiedValuePublisher: CurrentValueSubject<String, Never>(""))
    let imp_AnyObjCast = CurrentValuePublisher_AnyObjCast(retained_unverifiedValuePublisher: CurrentValueSubject<String, Never>(""))

    // TODO: - need to add Map operator for all CurrentValuePublisher types.
    // + measure map2
    // TODO: - measure direct subscript without map

    var subjectCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tCurrentValueSubject) = performMeasuredAction(count: outerLocal) { // reference measurement
      for _ in 0..<inner {
        currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &subjectCancellables)
      }
    }

    var subjectErasedCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tCurrentValueSubjectErased) = performMeasuredAction(count: outerLocal) { // reference measurement
      for _ in 0..<inner {
        currentValueSubject.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }.eraseToAnyPublisher()
          .sink { _ in }
          .store(in: &subjectErasedCancellables)
        // TODO: - is there difference to apply .eraseToAnyPublisher() in the end of chain or before it
      }
    }

    var imp_currentCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_current) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_current.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_currentCancellables)
      }
    }

    var imp_ExistentialCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_Existential) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_Existential.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_ExistentialCancellables)
      }
    }

    var imp_ClosureCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_Closure) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_Closure.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_ClosureCancellables)
      }
    }

    var imp_PointerCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_Pointer) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_Pointer.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_PointerCancellables)
      }
    }

    var imp_PointerInlineCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_PointerInline) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_PointerInline.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_PointerInlineCancellables)
      }
    }

    var imp_AnyObjCastCancellables = Array<AnyCancellable>(minimumCapacity: total)
    let (_, tImp_AnyObjCast) = performMeasuredAction(count: outerLocal) {
      for _ in 0..<inner {
        imp_AnyObjCast.map { $0 }.map { $0 }.map { $0 }.map { $0 }.map { "\($0)" }
          .sink { _ in }
          .store(in: &imp_AnyObjCastCancellables)
      }
    }
    
    let totalIterations = Double(total)

    let thCurrentValueSubject = totalIterations * (1000 / tCurrentValueSubject)
    let thCurrentValueSubjectErased = totalIterations * (1000 / tCurrentValueSubjectErased)

    let thImp_current = totalIterations * (1000 / tImp_current)
    let thImp_Existential = totalIterations * (1000 / tImp_Existential)
    let thImp_Closure = totalIterations * (1000 / tImp_Closure)
    let thImp_Pointer = totalIterations * (1000 / tImp_Pointer)
    let thImp_PointerInline = totalIterations * (1000 / tImp_PointerInline)
    let thImp_AnyObjCast = totalIterations * (1000 / tImp_AnyObjCast)

    printTable("Operators Chain Subscriptions per second",
               rows: [("  CurrentValueSubject time", tCurrentValueSubject),
                      ("  CurrentValueSubjectErased time", tCurrentValueSubjectErased),
                      ("  Imp_current time", tImp_current),
                      ("  Imp_Existential time", tImp_Existential),
                      ("  Imp_Closure time", tImp_Closure),
                      ("  Imp_Pointer time", tImp_Pointer),
                      ("  Imp_PointerInline time", tImp_PointerInline),
                      ("  Imp_AnyObjCast time", tImp_AnyObjCast),

                      ("CurrentValueSubject throughput", thCurrentValueSubject),
                      ("CurrentValueSubjectErased throughput", thCurrentValueSubjectErased),
                      ("Imp_current throughput", thImp_current),
                      ("Imp_Existential throughput", thImp_Existential),
                      ("Imp_Closure throughput", thImp_Closure),
                      ("Imp_Pointer throughput", thImp_Pointer),
                      ("Imp_PointerInline throughput", thImp_PointerInline),
                      ("AnyObjCast throughput", thImp_AnyObjCast)])
  }
}

extension CurrentValuePublisher_Closure {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher_Closure<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher_Closure<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

extension CurrentValuePublisher_Existential {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher_Existential<T, Failure> {
    func wrap(unboxingAny base: some Publisher<Output, Failure>) -> CurrentValuePublisher_Existential<T, Failure> {
      let map = Publishers.Map(upstream: base, transform: transform)
      return CurrentValuePublisher_Existential<T, Failure>(retained_unverifiedValuePublisher: map)
    }
    return wrap(unboxingAny: _base)
  }

  public func map2<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher_Existential<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher_Existential<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

extension CurrentValuePublisher_Any {
  public func map<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher_Any<T, Failure> {
    let map = Publishers.Map(upstream: _base, transform: transform)
    return CurrentValuePublisher_Any<T, Failure>(retained_unverifiedValuePublisher: map)
  }

  public func map2<T>(_ transform: @escaping (Output) -> T) -> CurrentValuePublisher_Any<T, Failure> {
    let map = Publishers.Map(upstream: self, transform: transform)
    return CurrentValuePublisher_Any<T, Failure>(retained_unverifiedValuePublisher: map)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 1

/// Closure-capturing imp.
/// `base: P` is captured by closure, no existential boxing
struct CurrentValuePublisher_Closure<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _subscribeClosure: (any Subscriber<Output, Failure>) -> Void

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P)
    where P.Output == Output, P.Failure == Failure {
    _subscribeClosure = { [base] subscriber in
      base.receive(subscriber: subscriber)
    }
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _subscribeClosure(subscriber)
  }
}

extension CurrentValuePublisher_Closure {
  public init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 2

/// Existential implementation.
/// `base: P` is wrapped by existential container.
struct CurrentValuePublisher_Existential<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _base: any Publisher<Output, Failure>

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P) where P.Output == Output, P.Failure == Failure {
    _base = base
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _base.receive(subscriber: subscriber)
  }
}

extension CurrentValuePublisher_Existential {
  init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 3

/// AnyPublisher implementation.
/// `base: P` is wrapped by AnyPublisher
struct CurrentValuePublisher_Any<Output, Failure: Error>: Publisher {
  @usableFromInline
  /* private */ internal let _base: AnyPublisher<Output, Failure>

  @inlinable
  internal init<P: Publisher>(retained_unverifiedValuePublisher base: P) where P.Output == Output, P.Failure == Failure {
    _base = base.eraseToAnyPublisher()
  }

  @inlinable
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _base.receive(subscriber: subscriber)
  }
}

extension CurrentValuePublisher_Any {
  init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 4

final class CurrentValuePublisher_Pointer<Output, Failure: Error>: Publisher {
  let storage: UnsafeMutableRawPointer
  let subscribeFunc: (UnsafeMutableRawPointer, any Subscriber<Output, Failure>) -> Void
  let deinitFunc: (UnsafeMutableRawPointer) -> Void

  init<P: Publisher>(retained_unverifiedValuePublisher publisher: P)
    where P.Output == Output, P.Failure == Failure {
    // Выделяем память вручную и копируем туда издателя
    let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<P>.size,
                                                   alignment: MemoryLayout<P>.alignment)
    pointer.initializeMemory(as: P.self, repeating: publisher, count: 1)

    storage = pointer
    subscribeFunc = { storage, subscriber in
      let typedPublisher = storage.assumingMemoryBound(to: P.self).pointee
      typedPublisher.receive(subscriber: subscriber)
    }
    deinitFunc = { storage in
      storage.assumingMemoryBound(to: P.self).deinitialize(count: 1)
      storage.deallocate()
    }
  }

  deinit {
    deinitFunc(storage)
  }

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    subscribeFunc(storage, subscriber)
  }
}

extension CurrentValuePublisher_Pointer {
  convenience init(_ subject: CurrentValueSubject<Output, Failure>) {
    self.init(retained_unverifiedValuePublisher: subject)
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 5

struct CurrentValuePublisher_Inline<Output, Failure: Error>: Publisher {
  // Буфер из 3 машинных слов (24 байта на 64-бит системах).
  // В него помещаются простые паблишеры (например, Publishers.Map, Just и т.д.)
  typealias Buffer = (Int, Int, Int)
//  private(set)
  var buffer: Buffer = (0, 0, 0)

  // Таблица функций для управления жизненным циклом и вызовами
  private struct WitnessTable {
    let receive: (UnsafeRawPointer, any Subscriber<Output, Failure>) -> Void
    let destroy: (UnsafeMutableRawPointer) -> Void
    let copy: (UnsafeRawPointer, UnsafeMutableRawPointer) -> Void
  }

  private let witnessTable: WitnessTable

  public init<P: Publisher>(retained_unverifiedValuePublisher publisher: P) where P.Output == Output, P.Failure == Failure {
    let size = MemoryLayout<P>.size
    let alignment = MemoryLayout<P>.alignment

    // Проверяем, помещается ли Publisher в наш inline-буфер
    if size <= MemoryLayout<Buffer>.size, alignment <= MemoryLayout<Buffer>.alignment {
      // --- INLINE СТРАТЕГИЯ ---
      witnessTable = WitnessTable(
        receive: { inlineBufferRawPtr, subscriber in
          let typedPtr = inlineBufferRawPtr.assumingMemoryBound(to: P.self)
          typedPtr.pointee.receive(subscriber: subscriber)
        },
        destroy: { inlineBufferMutablePtr in
          let typedPtr = inlineBufferMutablePtr.assumingMemoryBound(to: P.self)
          typedPtr.deinitialize(count: 1)
        },
        copy: { srcInlinePtr, destInlinePtr in
          let typedSrc = srcInlinePtr.assumingMemoryBound(to: P.self)
          let typedDest = destInlinePtr.assumingMemoryBound(to: P.self)
          typedDest.initialize(to: typedSrc.pointee)
        },
      )

      withUnsafeMutablePointer(to: &buffer) { bufferPtr in
        let rawBufferPtr = UnsafeMutableRawPointer(bufferPtr)
        let typedBufferPtr = rawBufferPtr.assumingMemoryBound(to: P.self)
        typedBufferPtr.initialize(to: publisher)
      }

    } else {
      let box = _PublisherHeapBox(publisher)

      witnessTable = WitnessTable(
        receive: { inlineBufferRawPtr, subscriber in
          let boxPtr = inlineBufferRawPtr.assumingMemoryBound(to: _PublisherHeapBox<P>.self)
          boxPtr.pointee.base.receive(subscriber: subscriber)
        },
        destroy: { inlineBufferMutablePtr in
          let boxPtr = inlineBufferMutablePtr.assumingMemoryBound(to: _PublisherHeapBox<P>.self)
          boxPtr.deinitialize(count: 1)
        },
        copy: { srcInlinePtr, destInlinePtr in
          let srcBoxPtr = srcInlinePtr.assumingMemoryBound(to: _PublisherHeapBox<P>.self)
          let destBoxPtr = destInlinePtr.assumingMemoryBound(to: _PublisherHeapBox<P>.self)
          // Копируем сильную ссылку на класс (ARC инкрементируется автоматически)
          destBoxPtr.initialize(to: srcBoxPtr.pointee)
        },
      )

      // Записываем указатель на HeapBox внутрь нашего буфера
      withUnsafeMutablePointer(to: &buffer) { bufferPtr in
        let rawBufferPtr = UnsafeMutableRawPointer(bufferPtr)
        let typedBufferPtr = rawBufferPtr.assumingMemoryBound(to: _PublisherHeapBox<P>.self)
        typedBufferPtr.initialize(to: box)
      }
    }
  }

  // Перенаправляем вызов подписчика через таблицу функций
  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    withUnsafePointer(to: buffer) { bufferPtr in
      let rawBufferPtr = UnsafeRawPointer(bufferPtr)
      witnessTable.receive(rawBufferPtr, subscriber)
    }
  }
}

extension CurrentValuePublisher_Inline {
  // Деструктор структуры (вызывается при выходе из области видимости)
  @_transparent
  public mutating func destroy() {
    withUnsafeMutablePointer(to: &buffer) { bufferPtr in
      let rawBufferPtr = UnsafeMutableRawPointer(bufferPtr)
      witnessTable.destroy(rawBufferPtr)
    }
  }

  // Ручная копия (нужна, если структура передается по значению)
  // Swift вызывает внутренний метод копирования, но для кастомных структур с RawPointer
  // иногда приходится явно управлять логикой, если мы пишем аналоги стандартной библиотеки.
}

fileprivate final class _PublisherHeapBox<P> {
  let base: P
  init(_ base: P) {
    self.base = base
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

// MARK: - CurrentValuePublisher 6

// 1. Generic container for Publisher
// final class should be optimized.
@usableFromInline
internal final class PublisherManagedBox<P: Publisher> {
  @usableFromInline internal let base: P

  @inlinable
  init(_ base: P) {
    self.base = base
  }
}

struct CurrentValuePublisher_AnyObjCast<Output, Failure: Error>: Publisher {
  // Opaque AnyObject
  @usableFromInline internal let _storage: AnyObject

  // Function that can cast to generic type
  @usableFromInline internal let _receiveFunc: (AnyObject, any Subscriber<Output, Failure>) -> Void

//  @inline(always) // lead to compiler crash
  init<P: Publisher>(retained_unverifiedValuePublisher publisher: P) where P.Output == Output, P.Failure == Failure {
    let box = PublisherManagedBox(publisher)
    _storage = box

    // Create closure without capturing publisher
    _receiveFunc = { storage, subscriber in
      let castedBox = storage as! PublisherManagedBox<P>
      castedBox.base.receive(subscriber: subscriber)
    }
  }

  @inline(always)
  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    _receiveFunc(_storage, subscriber)
  }
}
