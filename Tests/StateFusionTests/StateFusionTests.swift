import Combine
import StateFusion

final class Examples: Sendable {
  fileprivate let bag = CancellationBag()
  
  typealias PlayState = LoadingState<String, NetworkError>
}

extension Examples {
  func stateOperators(actions: Actions) {
//    let state = PublishedState<PlayState>(.isLoading)
//
//    let dataLoaded = Empty<String, Never>(completeImmediately: false)
//    let loadingError = Empty<NetworkError, Never>(completeImmediately: false)
//
//    let closeButtonTap = Empty<Void, Never>(completeImmediately: false)
//    let mainButtonTap = Empty<Void, Never>(completeImmediately: false)
//    let didSelectProductWithID = Empty<UInt64, Never>(completeImmediately: false)
//    let didSelectItemWithID = Empty<UInt64, Never>(completeImmediately: false)
//
//    let promoCodeDeactivationError = Empty<NetworkError, Never>(completeImmediately: false)
//
//    bag.insert {
//      dataLoaded.handle(reducing: state) { state, loadedData in
//        guard case .isLoading = state else { return .ignore }
//        return .transition(to: .dataLoaded(loadedData))
//      }
//
//      loadingError.filter(reducing: state, output: ContinuousClock.Instant.self) { state, error in
//        guard case .isLoading = state else { return .ignore }
//        if Bool.random() {
//          return .transition(to: .loadingError(error), output: .now)
//        } else {
//          return .handled(output: .now) // TODO: - найти пример для такого кейса
//        }
//      }
//      .sink(receiveValue: { error, timeStamp in print(error, timeStamp) })
//
//      // filter(by
//      
//      closeButtonTap.filter(by: state) {
//        guard case .dataLoaded = $0 else { return .ignore }; return .handled
//      }
//      .sink(receiveValue: actions.closeScreen)
//      
//      mainButtonTap.filter(by: state, output: String.self) {
//        guard case let .dataLoaded(text) = $0 else { return .ignore }; return .handled(output: text)
//      }
//      .sink(receiveValue: { text in actions.routeTo(.fuzzySearch(text: text)) })
//
//      didSelectProductWithID.filter(by: state) {
//        guard case .dataLoaded = $0 else { return .ignore }; return .handled
//      }
//      .sink(receiveValue: { productID in actions.routeTo(.product(id: productID)) })
//
//      didSelectItemWithID.filter(by: state, output: String.self) {
//        guard case .dataLoaded(let text) = $0 else { return .ignore }; return .handled(output: text)
//      }
//      .sink(receiveValue: { itemID, text in actions.routeTo(.search(text: text, itemID: itemID)) })
//    }
  }
}

struct Actions {
  let routeTo: (ScreenRoute) -> Void
  let closeScreen: () -> Void
}

enum ScreenRoute {
  case product(id: UInt64)
  case search(text: String, itemID: UInt64)
  case fuzzySearch(text: String)
}

struct ValidationError: Error {}

struct NetworkError: Error {}

@inline(never) @_optimize(none)
public func blackHole<T>(_ thing: T) {
  _ = thing
}
