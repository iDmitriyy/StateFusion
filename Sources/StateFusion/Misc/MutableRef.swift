//
//  MutableRef.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 11.06.2026.
//

import Builtin

#if compiler(>=6.4)
@available(anyAppleOS 9999, *)
    internal var _mutableRef: MutableRef<StateEntity>
    #else
    internal var _mutableRef: _MutableRef<StateEntity>
#endif

/// https://github.com/swiftlang/swift/blob/72a2eabe09c60f28fae0e45104aa7ac37a6e3677/stdlib/public/core/MutableRef.swift
@frozen
@safe
public struct _MutableRef<Value: ~Copyable>: ~Copyable, ~Escapable {
  @usableFromInline
  let pointer: UnsafeMutablePointer<Value>

  @_alwaysEmitIntoClient
  @_lifetime(&value)
  @_transparent
  public init(_ value: inout Value) {
    unsafe pointer = UnsafeMutablePointer(Builtin.unprotectedAddressOf(&value))
  }
  
  @unsafe
  @_alwaysEmitIntoClient
  @_lifetime(&owner)
  @_transparent
  public init<Owner: ~Copyable & ~Escapable>(
    unsafeAddress pointer: UnsafeMutablePointer<Value>,
    mutating owner: inout Owner
  ) {
    unsafe self.pointer = pointer
  }
}

extension _MutableRef: @unchecked Sendable where Value: Sendable & ~Copyable {}

extension _MutableRef where Value: ~Copyable {
  @_alwaysEmitIntoClient
  @_transparent
  public var value: Value {
    @_unsafeSelfDependentResult
    borrow {
      unsafe pointer.pointee
    }

    @_unsafeSelfDependentResult
    mutate {
      unsafe &pointer.pointee
    }
  }
}

//@frozen
//@safe
//public struct _MutableRef<Value: ~Copyable>: ~Copyable, ~Escapable {
//  @usableFromInline
//  let pointer: UnsafeMutablePointer<Value>
//  
//  @_alwaysEmitIntoClient
//  @_lifetime(&value)
//  @_transparent
//  public init(_ value: inout Value) {
//    unsafe pointer = UnsafeMutablePointer(Builtin.unprotectedAddressOf(&value))
//  }
//}
//
//extension _MutableRef: @unchecked Sendable where Value: Sendable & ~Copyable {}
//
//extension _MutableRef where Value: ~Copyable {
//  /// Dereferences the mutable reference allowing for in-place reads and writes
//  /// to the underlying value.
//  @_alwaysEmitIntoClient
//  @_transparent
//  public var value: Value {
//    @_unsafeSelfDependentResult
//    borrow {
//      unsafe pointer.pointee
//    }
//
//    @_unsafeSelfDependentResult
//    mutate {
//      unsafe &pointer.pointee
//    }
//  }
//}
