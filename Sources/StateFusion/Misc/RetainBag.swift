//
//  RetainBag.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 04.06.2026.
//

public final class RetainBag { // Improvement: make ~Copyable to prevent sharing | capture outer type for log info
  private var retainedObjects: [any AnyObject] = []

  internal init() {}

  public final func add(object: any AnyObject) {
    guard !retainedObjects.contains(where: { $0 === object }) else {
      return // RIBs.log(.warning, RIBsLogEntry(code: .valueCollision, info: ["object": "\(object)"]))
    }

    retainedObjects.append(object)
  }

  public final func add(instance: consuming some ~Copyable) {
    let wrappedInstance = NonCopyableWrapper(instance: instance)
    retainedObjects.append(wrappedInstance)
  }

  private final class NonCopyableWrapper<T: ~Copyable> {
    let instance: T

    init(instance: consuming T) {
      self.instance = instance
    }
  }
}
