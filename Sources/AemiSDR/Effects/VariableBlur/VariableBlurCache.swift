//
//  VariableBlurCache.swift
//  AemiSDR
//

/// VariableBlurCache provides variable blur mask generation using shared kernels from CIKernelCache.
///
/// All kernel properties are inherited from the base class. Non-inverted mask kernels
/// have been consolidated: callers pass `inverted = 0` to the alpha mask variants.
/// This subclass exists for type-namespacing and logging context.
final class VariableBlurCache: CIKernelCache {}
