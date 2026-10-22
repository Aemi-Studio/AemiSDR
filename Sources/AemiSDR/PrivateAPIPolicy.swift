import Abysm

/// The host application's policy governing private Apple framework calls.
///
/// When disabled, all private Cocoa runtime calls, private KVC accesses, private layer classes
/// (`CABackdropLayer`), and private CoreAnimation filters (`CAFilter`) are suppressed and degrade
/// gracefully to safe public fallbacks. Setting this policy is thread-safe and takes effect immediately.
public enum PrivateAPIPolicy: Sendable {
    /// Whether private runtime APIs may be called. Defaults to `true`.
    public static var isEnabled: Bool {
        get { RuntimeAccess.isEnabled }
        set { RuntimeAccess.isEnabled = newValue }
    }
}
