//
//  ObservationKind.swift
//  StateFusion
//
//  Created by Dmitriy Ignatyev on 16.07.2026.
//

// TODO: - this should better be modeled as protocol extension rather then enum

public enum ObservationSchedulingVariant {
  /// Executes work immediately on the current thread without any asynchronous hopping.
  ///
  /// Use this for high-performance pipelines where data processing is lightweight (e.g., parsing a small local enum)
  /// and you want to completely eliminate thread-switching overhead.
  ///
  /// ```swift
  /// publisher
  ///   .observe(on: .sync) // No context switch, continuous execution
  /// ```
  case sync

  /// Dispatches work concurrently to the system's global asynchronous pool.
  ///
  /// Use this when downstream operations are heavy, independent, and do not rely on sequential ordering.
  /// It maximizes CPU utilization by spreading work across multiple cores.
  ///
  /// > Warning: Ensure downstream subscribers are thread-safe, as events can arrive concurrently.
  ///
  /// ```swift
  /// imagesPublisher
  ///   .observe(on: .concurrentAsync(priority: .utility))
  ///   .map { heavyImageProcessing(\$0) } // Runs across multiple cores
  /// ```
  case concurrentAsync(priority: TaskPriority)
  
  /// Schedules work asynchronously on a serial background context with a specific priority.
  ///
  /// Use this when downstream processing must maintain strict FIFO (First-In, First-Out) ordering,
  /// but you must free up the calling thread immediately.
  ///
  /// * Use `.high` or `.medium` for user-initiated background tasks like loading local database records.
  /// * Use `.low` or `.background` for non-urgent tasks like pre-fetching assets or saving analytics logs.
  ///
  /// ```swift
  /// publisher
  ///   .observe(on: .serialAsync(priority: .userInitiated))
  /// ```
  case serialAsync(priority: TaskPriority)
}
