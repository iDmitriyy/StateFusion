//
//  VIPBinder.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 02.06.2026.
//

public protocol IOTransformer: AnyObject {
  associatedtype Input
  associatedtype Output
  
  func transform(input: Input) -> Output
}

//===-------------------------------------------------------------------------------------------------------------------===//

public protocol BindableView {
  associatedtype Input
  associatedtype Output

  func getOutput() -> Output
  func bindWith(input: Input)
}

public protocol BindableViewController: BindableView, AnyObject {}

//===-------------------------------------------------------------------------------------------------------------------===//

public struct VIPOutput<VOutput, IOutput, POutput> {
  public let viewOutput: VOutput
  public let interactorOutput: IOutput
  public let presenterOutput: POutput
  
  @usableFromInline
  init(viewOutput: VOutput, interactorOutput: IOutput, presenterOutput: POutput) {
    self.viewOutput = viewOutput
    self.interactorOutput = interactorOutput
    self.presenterOutput = presenterOutput
  }
}

//===-------------------------------------------------------------------------------------------------------------------===//

public enum VIPBinder {
  public typealias VIOutput<V, I> = (viewOutput: V, interactorOutput: I)
  
  /// Новый вариант биндинга, без принудительной загрузки вью. Название временное, поменять после рефакторинга.
  @discardableResult
  @inlinable
  public static func bind<V, I, P>(viewController: V, interactor: I, presenter: P) -> VIPOutput<V.Output, I.Output, P.Output>
    where V: BindableView, I: IOTransformer, P: IOTransformer,
    V.Output == I.Input, I.Output == P.Input, P.Output == V.Input {
    let viewOutput = viewController.getOutput()
    let interactorOutput = interactor.transform(input: viewOutput)
    let presenterOutput = presenter.transform(input: interactorOutput)
    viewController.bindWith(input: presenterOutput)

    return VIPOutput(viewOutput: viewOutput, interactorOutput: interactorOutput, presenterOutput: presenterOutput)
  }

  /// Вариант биндинга, когда в модуле отсутствует Preseneter
  @discardableResult
  @inlinable
  public static func bind<V, I>(viewController: V, interactor: I) -> VIOutput<V.Output, I.Output>
  where V: BindableView, I: IOTransformer, V.Output == I.Input, I.Output == V.Input {
    let viewOutput = viewController.getOutput()
    let interactorOutput = interactor.transform(input: viewOutput)
    viewController.bindWith(input: interactorOutput)

    return (viewOutput: viewOutput, interactorOutput: interactorOutput)
  }
}
