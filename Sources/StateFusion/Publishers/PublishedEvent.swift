//
//  PublishedEvent.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public import Combine

/// Обертка, которая позволяет использовать PublishSubject как Observable.
/// Это нужно в случаях, когда accept элементов делается только в 1 месте, а подписки делаются в нескольких местах.
/// Так сделано для того, чтобы по символу $ в начале названия было визуально заметно в каких местах происходит
/// передача элементов в реактивные стримы.
///
/// - wrappedValue – когда нужно только подписываться на поток данных и вызов .accept(value) не требуется.
/// Нужно, например, в имплементации StateTransform.
/// - projectedValue – когда нужно за-accept'ить данные в PublishSubject. Как правило, это нужно внутри самого интерактора.
@propertyWrapper
public final class PublishedEvent<Output> {
  public final let wrappedValue: InfalliblePublisher<Output>

  public final var projectedValue: PublishedEvent<Output> {
    self
  }

  private let _subject = PassthroughSubject<Output, Never>()

  public init() {
    wrappedValue = _subject.eraseToAnyPublisher()
  }
  
  public final func send(_ input: Output) {
    _subject.send(input)
  }
}
