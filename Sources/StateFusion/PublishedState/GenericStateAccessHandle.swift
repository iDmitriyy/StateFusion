//
//  GenericStateAccessHandle.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 11.06.2026.
//

import Builtin

// MARK: - DataState AccessHandle

// https://github.com/swiftlang/swift/blob/a0b56234e1597d77b6d8a1154086590fad257196/stdlib/public/core/LifetimeManager.swift#L125

// Improvement: MutableRef can be used when available:
// https://github.com/swiftlang/swift/blob/72a2eabe09c60f28fae0e45104aa7ac37a6e3677/stdlib/public/core/MutableRef.swift#L17

public struct GenericStateAccessHandle<StateEntity: ~Copyable>: ~Copyable, ~Escapable {
  public var stateEntity: StateEntity {
    borrow {
      _mutableRef.value
    }
    mutate {
      _isMutablyAccessed = true
      return &_mutableRef.value
    }
  }

  @usableFromInline
  internal var isMutablyAccessed: Bool {
    consuming get { _isMutablyAccessed }
  }

  private var _isMutablyAccessed: Bool = false

  /// private
  @usableFromInline
  /* private */ internal var _mutableRef: _MutableRef<StateEntity>

  @_alwaysEmitIntoClient
  @_lifetime(copy mutableRef)
  @_transparent
  internal init(mutableRef: consuming _MutableRef<StateEntity>) {
    _mutableRef = mutableRef
  }
}

@available(*, unavailable, message: "AccessHandle is restricted to local use within a `access` closure; it cannot be Sendable and must not cross isolation boundaries.")
extension GenericStateAccessHandle: Sendable {}
