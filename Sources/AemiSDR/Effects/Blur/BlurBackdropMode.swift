/// How a blur view draws (ADR-0009): the private backdrop, the system's material in its place, or an opaque fill when the person
/// asked for less transparency (Accessibility > Display > Reduce Transparency).
enum BlurBackdropMode: Sendable, Equatable {
    case backdrop, material, opaque

    static func choose(reduceTransparency: Bool, backdropAvailable: Bool) -> Self {
        if reduceTransparency { return .opaque }
        return backdropAvailable ? .backdrop : .material
    }
}
