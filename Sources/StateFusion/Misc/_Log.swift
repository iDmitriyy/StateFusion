//
//  _Log.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 11.06.2026.
//

import Synchronization

public enum StateFusionLogLevel: Sendable, Equatable {
  case warning
  case critical
}

public typealias StateFusionLoggingObserver = @Sendable ((level: StateFusionLogLevel, entry: StateFusionLogEntry)) -> Void

public enum StateFusionLogging {
  fileprivate static let _observer = Mutex<StateFusionLoggingObserver?>(nil)
  
  public static func injectOnce(loggingObserver: @escaping StateFusionLoggingObserver) {
    _observer.withLock { maybeObserver in
      if let injectedObserver = maybeObserver {
        let message = "Trying to inject logging observer more than once."
        let error = LogEntry(code: .logger, message: message)
        injectedObserver((level: .warning, entry: error))
        loggingObserver((level: .warning, entry: error))
        assertionFailure(message)
      } else {
        maybeObserver = loggingObserver
      }
    }
  }
}

internal func log(_ level: StateFusionLogLevel, _ entry: StateFusionLogEntry) {
  StateFusionLogging._observer.withLock { $0 }?((level: level, entry: entry))
  
  let message = "StateFusion error – code: \(entry.code) (\(entry.codeString)), message: \(entry.message)"
  assertionFailure(message)
}

internal typealias LogEntry = StateFusionLogEntry
internal typealias ErrorInfo = [String: any Sendable & Equatable & CustomStringConvertible]

public struct StateFusionLogEntry: Sendable {
  public let code: Int
  public let codeString: String
  public let message: String
  public let info: [String: any Sendable & Equatable & CustomStringConvertible]
  public let file: StaticString
  public let line: UInt
    
  fileprivate init(code: Int,
                   codeString: String,
                   message: String,
                   info: ErrorInfo,
                   file: StaticString,
                   line: UInt) {
    self.code = code
    self.codeString = codeString
    self.message = message
    self.info = info
    self.file = file
    self.line = line
  }
}

extension StateFusionLogEntry {
  internal init(code: InternalErrorCode,
                message: String,
                info: ErrorInfo = [:],
                file: StaticString = #fileID,
                line: UInt = #line) {
    self.init(code: code.rawValue, codeString: "\(code)", message: message, info: info, file: file, line: line)
  }
}

internal enum InternalErrorCode: Int {
  case logger = 0
  case unexpectedNilObject = 1
  
  case publishedStateRetained = 20
  case snapshotSourceMismatch
}
