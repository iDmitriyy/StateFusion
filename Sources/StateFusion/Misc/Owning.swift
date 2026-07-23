//
//  Owning.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 23.07.2026.
//

internal enum Owning<T: AnyObject> {
  case retained(T)
  case borrowed(Weak<T>)
}

internal struct Weak<T: AnyObject> {
  weak let instance: T?
}

internal struct Unowned<T: AnyObject> {
  unowned let instance: T
}
