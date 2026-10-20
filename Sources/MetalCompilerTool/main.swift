#if os(macOS)
    import Foundation
    import MetalCompilerCore

    // The logic lives in MetalCompilerCore so it can be tested; this file only starts it.
    exit(MetalCompilerMain.run(arguments: CommandLine.arguments))
#else
    // This tool is only meant to run on macOS during the build process.
    // It should never be compiled or run on iOS/tvOS/watchOS.
    fatalError("MetalCompilerTool can only run on macOS")
#endif
