// Animation loop helper for managing frame timing and timeouts
//
// NOTE: This implementation uses async/await with Task.sleep(for:)
// for non-blocking execution. This is essential for concurrent demos running
// on multiple Flaschen Taschen layers simultaneously. Task.sleep() yields
// control to the event loop, allowing other demos to execute cooperatively.

import Foundation

// MARK: - Animation Loop

/// Helper for managing animation loop timing with async/await support
/// Uses @unchecked Sendable for thread-safe concurrent execution across multiple demo layers
public class AnimationLoop: @unchecked Sendable {
    private let startTime: Date
    private let timeout: Double
    private let delay: Duration
    public var frameCount: Int = 0

    /// Initialize animation loop with timeout and frame delay
    /// - Parameters:
    ///   - timeout: Maximum duration in seconds (default 24 hours)
    ///   - delay: Delay between frames in milliseconds
    public init(timeout: Double = 60 * 60 * 24.0, delay: Int = 50) {
        self.startTime = Date()
        self.timeout = timeout
        // Convert milliseconds to Duration
        self.delay = .milliseconds(delay)
    }

    /// Check if animation should continue
    public nonisolated func shouldContinue() -> Bool {
        return Date().timeIntervalSince(startTime) <= timeout
    }

    /// Yield control for the configured frame delay
    /// Note: Uses non-blocking Task.sleep(for:) which yields to the event loop
    /// This allows other tasks (like concurrent demos) to execute
    public nonisolated func sleep() async throws {
        try await Task.sleep(for: delay)
    }

    /// Increment frame counter (resets at Int.max to prevent overflow)
    public func nextFrame() {
        frameCount += 1
        if frameCount == Int.max {
            frameCount = 0
        }
    }

    /// Get elapsed time since loop started
    public nonisolated var elapsed: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }

    /// Run the animation loop with an async callback
    /// - Parameter frameCallback: Called for each frame, receives frame count
    public func run(frameCallback: @escaping (Int) async -> Void) async {
        while shouldContinue() {
            await frameCallback(frameCount)
            nextFrame()
            do {
                try await sleep()
            } catch {
                // Task was cancelled, exit loop gracefully
                break
            }
        }
    }
}

// MARK: - Convenience Function

/// Run a simple async animation loop
/// - Parameters:
///   - timeout: Maximum duration in seconds
///   - delay: Frame delay in milliseconds
///   - onFrame: Callback invoked each frame with frame count
public func runAnimationLoop(
    timeout: Double = 60 * 60 * 24.0,
    delay: Int = 50,
    onFrame: @escaping (Int) async -> Void
) async {
    let loop = AnimationLoop(timeout: timeout, delay: delay)
    await loop.run(frameCallback: onFrame)
}
