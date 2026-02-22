//
//  AlphaMaskCache.swift
//  AemiSDR
//

/// AlphaMaskCache provides alpha mask generation using shared kernels from CIKernelCache.
///
/// All kernel properties are inherited from the base class. This subclass exists
/// for type-namespacing and logging context.
final class AlphaMaskCache: CIKernelCache {}
