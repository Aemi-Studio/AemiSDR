#if os(iOS)
    import Metal
    import Synchronization

    /// One source reservation. The view owns it while it may redraw; each submitted GPU read owns another hold.
    /// Immutable texture/closure metadata may cross threads; pixel access is synchronized by the bridge and GPU.
    final class TextureSourceLease: @unchecked Sendable {
        let texture: MTLTexture
        private let onConsumed: (@Sendable () -> Void)?

        init(texture: MTLTexture, onConsumed: (@Sendable () -> Void)? = nil) {
            self.texture = texture
            self.onConsumed = onConsumed
        }

        func beginRead() -> TextureReadLease { TextureReadLease(source: self) }

        deinit { onConsumed?() }
    }

    /// A GPU submission's hold, independently and idempotently completed from any thread.
    final class TextureReadLease: Sendable {
        private let source: Mutex<TextureSourceLease?>

        init(source: TextureSourceLease) { self.source = Mutex(source) }

        func finish() {
            let released = source.withLock { stored in
                let previous = stored
                stored = nil
                return previous
            }
            // A final release can run an arbitrary caller callback. Do it after unlocking, so reentrancy cannot
            // deadlock this hold. A retained completion closure no longer pins the source once finish returns.
            withExtendedLifetime(released) {}
        }
    }
#endif
