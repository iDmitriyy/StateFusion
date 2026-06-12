//
//  Test.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 11.06.2026.
//

@testable import StateFusion
import Testing

struct PlaygroundTest {
  @Test(.serialized, arguments: [true, false])
  func playground(shouldMutate: Bool) {
//    var isAMutablyAccessed = false
    var stateA = ""
    let addressBeforeA = getBufferAddress(stateA)
    mutate(value: &stateA) {
      shouldMutate ? $0.append("!") : blackHole($0)
    }
    let isAMutablyAccessed = (getBufferAddress(stateA) != addressBeforeA)
    
    var _stateB: String = ""
    var isBMutablyAccessed = false
    var stateB: String {
      yielding borrow {
        yield _stateB
      }
      yielding mutate {
        isBMutablyAccessed = true
        yield &_stateB
      }
    }

    mutate(value: &stateB) {
      shouldMutate ? $0.append("!") : blackHole($0)
    }

    var isCMutablyAccessed1 = false
    var stateC = "" {
      didSet {
        isCMutablyAccessed1 = true
      }
    }
    let isCMutablyAccessed2 = withUnsafeMutablePointer(to: &stateC) { mutablePointer in
      var accessHandle = GenericStateAccessHandle(pointer: mutablePointer)
      mutate(accessHandle: &accessHandle) {
        shouldMutate ? $0.stateEntity.append("!") : blackHole($0.stateEntity)
      }
      return accessHandle.isMutablyAccessed
    }

    var isDMutablyAccessed1 = false
    var stateD = "" {
      didSet {
        isDMutablyAccessed1 = true
      }
    }
    var isDMutablyAccessed2 = false
//    do {
//      var accessHandle = GenericStateAccessHandle(mutableStateEntity: &stateD)
//      let ref = MutableRef(&stateD)
    if shouldMutate {
//        ref.value.append("!")
//        accessHandle.stateEntity.append("!")
    } else {
//        blackHole(ref.value)
//        blackHole(accessHandle.stateEntity)
    }
//      isDMutablyAccessed2 = accessHandle.isMutablyAccessed
//    }

    var isEMutablyAccessed = false
    var stateE = "" {
      didSet {
        isEMutablyAccessed = true
      }
    }
    withUnsafeMutablePointer(to: &stateE) { mutablePointer in
      shouldMutate ? mutablePointer.pointee.append("!") : blackHole(mutablePointer.pointee)
    }

    let strings = [stateA, stateB, stateC]
    #expect(strings == Array(repeating: shouldMutate ? "!" : "", count: 3))

    #expect(isAMutablyAccessed) // always true because of copy made passing as inout
    #expect(isBMutablyAccessed) // always true because mutat

    #expect(isCMutablyAccessed1 == shouldMutate)
    #expect(isCMutablyAccessed2 == shouldMutate)

    #expect(isDMutablyAccessed1 == shouldMutate)
    #expect(isDMutablyAccessed2 == shouldMutate)

    #expect(isEMutablyAccessed == shouldMutate)
    print("__stateE", stateE, shouldMutate, isEMutablyAccessed)
  }
  
  @Test(.serialized, arguments: [true, false])
  func `playground ref`(shouldMutate: Bool) {
//    var isMutablyAccessed = false
//    var state = "" {
//      didSet {
//        isMutablyAccessed = true
//      }
//    }
//
//    let ref = _MutableRef(&state)
//    if shouldMutate {
//      ref.value.append("!")
//    } else {
//      blackHole(ref.value)
//    }
  }

  @Test(.serialized, arguments: [true, false])
  func `playground Mutable Pointer`(shouldMutate: Bool) {
//    var isMutablyAccessed = false
//    var state = "" {
//      didSet {
//        isMutablyAccessed = true
//      }
//    }
//
//    withUnsafeMutablePointer(to: &state) { mutablePointer in
//      shouldMutate ? mutablePointer.pointee.append("!") : blackHole(mutablePointer.pointee)
//    }
  }

  private func mutate<T: ~Copyable>(value: inout T, mutation: (inout T) -> Void) {
    mutation(&value)
  }

  private func mutate<T: ~Copyable>(accessHandle: inout GenericStateAccessHandle<T>,
                                    mutation: (inout GenericStateAccessHandle<T>) -> Void) {
    mutation(&accessHandle)
  }
  
  // Тип, который знает свой честный физический адрес
  public struct IdentityTracker {
      private let originalAddress: Int
      public var mutationCount = 0
      
      public init() {
          // Запоминаем адрес в момент создания
          var dummy = 0
          self.originalAddress = Int(bitPattern: UnsafeRawPointer(&dummy))
      }
      
      // Метод для проверки, что мы находимся в той же ячейке памяти
      public mutating func verifyInPlace() -> Bool {
          withUnsafePointer(to: self) { currentPointer in
              let currentAddress = Int(bitPattern: currentPointer)
              // Если адреса совпадают — это in-place доступ без копирования
              return currentAddress == originalAddress
          }
      }
      
      public mutating func performMutation() {
          mutationCount += 1
      }
  }
}

func getBufferAddress(_ str: String) -> Int {
  var copy = str
  return copy.withUTF8 { Int(bitPattern: $0.baseAddress) }
}
