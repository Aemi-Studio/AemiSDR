import Foundation

/// One filter a recipe asks for: its `CAFilter` type and the inputs to set, in order (ADR-0009). Pure data: building the filter is
/// `BlurFilterFactory`'s job, through Abysm.
struct BlurFilterSpec: Sendable, Equatable {
    enum Value: Sendable, Equatable {
        case number(String, Double)
        case flag(String, Bool)
        case mask(String, BlurMask)

        var key: String {
            switch self {
            case .number(let key, _), .flag(let key, _), .mask(let key, _): key
            }
        }
    }

    let type: String
    let values: [Value]
}
