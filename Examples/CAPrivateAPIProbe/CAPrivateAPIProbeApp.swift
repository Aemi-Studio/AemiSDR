//
//  CAPrivateAPIProbeApp.swift
//  CAPrivateAPIProbe
//
//  Enumerates ALL CA-prefixed classes from the ObjC runtime, introspects
//  their properties/methods/protocols/ivars, and exports a full JSON report.
//
//  Runtime enumeration + introspection happens in CARuntimeProbe.m (pure ObjC)
//  to avoid Swift metadata realization crashes on partially-loaded classes.
//

import SwiftUI
import QuartzCore
import ObjectiveC
import UIKit

// MARK: - ViewModel

@MainActor
final class CAProbeViewModel: ObservableObject {
    @Published var classDetails: [[String: Any]] = []
    @Published var underscoreClassDetails: [[String: Any]] = []
    @Published var criticalAPIs: [CriticalAPIResult] = []
    @Published var backdropLiveTest: String = "Not tested"
    @Published var totalCAClasses: Int = 0
    @Published var totalUnderscoreClasses: Int = 0
    @Published var isScanning = false
    @Published var exportedFilePath: String?

    /// Prefixes to scan for private classes.
    /// `_CA` catches ALL private CoreAnimation/QuartzCore classes.
    /// `_UIVisualEffect`, `_UIBackdrop`, `_UICustomBlur` catch UIKit visual effect internals.
    private let underscorePrefixes = [
        "_CA",              // All private CoreAnimation classes
        "_UIVisualEffect",  // Visual effect internals
        "_UIBackdrop",      // Backdrop view internals
        "_UICustomBlur",    // Custom blur effect
    ]

    struct CriticalAPIResult: Identifiable {
        let id = UUID()
        let name: String
        let exists: Bool
        let detail: String
    }

    func scan() {
        isScanning = true
        classDetails = probeRuntime()
        underscoreClassDetails = probeUnderscoreRuntime()
        criticalAPIs = testCriticalAPIs()
        backdropLiveTest = testBackdropLayerLive()
        isScanning = false
    }

    // MARK: - Runtime Probe

    private func probeRuntime() -> [[String: Any]] {
        let names = enumerateClassNames("CA") as [String]
        totalCAClasses = names.count

        return names.compactMap { name -> [String: Any]? in
            probeClassDetails(name) as [String: Any]?
        }
    }

    private func probeUnderscoreRuntime() -> [[String: Any]] {
        var allNames: [String] = []
        for prefix in underscorePrefixes {
            let names = enumerateClassNames(prefix) as [String]
            allNames.append(contentsOf: names)
        }
        // Deduplicate and sort
        let unique = Array(Set(allNames)).sorted()
        totalUnderscoreClasses = unique.count

        return unique.compactMap { name -> [String: Any]? in
            probeClassDetails(name) as [String: Any]?
        }
    }

    // MARK: - Critical APIs

    private func testCriticalAPIs() -> [CriticalAPIResult] {
        var results: [CriticalAPIResult] = []

        let criticalClasses: [(name: String, usage: String)] = [
            ("CABackdropLayer", "BackdropCaptureView.layerClass — captures composited content"),
            ("CAFilter", "VariableBlur gaussian blur filter creation"),
            ("_UICustomBlurEffect", "VisualEffect custom blur configuration"),
            ("_UIVisualEffectBackdropView", "VisualEffect internal backdrop view"),
            ("_UIVisualEffectSubview", "VisualEffect internal overlay subview"),
            ("_UIBackdropViewSettings", "BackdropBlur system style introspection"),
        ]

        for (name, usage) in criticalClasses {
            let cls: AnyClass? = NSClassFromString(name)
            results.append(CriticalAPIResult(
                name: name,
                exists: cls != nil,
                detail: cls != nil
                    ? "Available — \(usage)"
                    : "MISSING — \(usage)"
            ))
        }

        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let instance = backdropClass.init()
            for (key, usage) in [
                // Legacy keys (used by AemiSDR pre-iOS 26)
                ("layerUsesCoreImageFilters", "LEGACY — Disable CI filtering on backdrop"),
                ("windowServerAware", "LEGACY — Enable window-server composition"),
                // Still-working keys
                ("groupName", "Backdrop group coordination"),
                ("scale", "Render scale factor"),
                // New iOS 26 keys
                ("enabled", "NEW — Enable/disable backdrop capture"),
                ("captureOnly", "NEW — Capture without rendering filters"),
                ("backdropRect", "NEW — Capture subrect"),
                ("allowsInPlaceFiltering", "NEW — In-place filter processing"),
                ("reducesCaptureBitDepth", "NEW — Lower bit depth for perf"),
                ("updateRate", "NEW — Capture update rate"),
                ("disablesOccludedBackdropBlurs", "NEW — Optimize occluded blurs"),
                ("tracksLuma", "NEW — Luma tracking for materials"),
            ] {
                let responds = instance.responds(to: NSSelectorFromString(key))
                    || instance.responds(to: NSSelectorFromString("is\(key.prefix(1).uppercased())\(key.dropFirst())"))
                results.append(CriticalAPIResult(
                    name: "CABackdropLayer.\(key)",
                    exists: responds,
                    detail: responds ? "Responds — \(usage)" : "NOT RESPONDING — \(usage)"
                ))
            }
        }

        if let filterClass = NSClassFromString("CAFilter") as? NSObject.Type {
            let sel = NSSelectorFromString("filterWithType:")
            let hasFactory = filterClass.responds(to: sel)
            results.append(CriticalAPIResult(
                name: "CAFilter.filterWithType:",
                exists: hasFactory,
                detail: hasFactory ? "Available" : "MISSING"
            ))
            if hasFactory {
                for filterType in ["gaussianBlur", "colorSaturate"] {
                    let f = filterClass.perform(sel, with: filterType)?.takeUnretainedValue()
                    results.append(CriticalAPIResult(
                        name: "CAFilter(\(filterType))",
                        exists: f != nil,
                        detail: f != nil ? "Created OK" : "FAILED"
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Live Backdrop Test

    private func testBackdropLayerLive() -> String {
        guard let cls = NSClassFromString("CABackdropLayer") as? CALayer.Type else {
            return "CABackdropLayer class not found — removed in this OS version"
        }

        let layer = cls.init()
        var report: [String] = ["Instantiated: \(type(of: layer))"]

        // Test legacy keys
        report.append("\n--- Legacy Keys ---")
        for (key, value) in [("layerUsesCoreImageFilters", false), ("windowServerAware", true)] as [(String, Any)] {
            if layer.responds(to: NSSelectorFromString(key)) {
                layer.setValue(value, forKey: key)
                let readBack = layer.value(forKey: key)
                report.append("\(key) = \(value)  OK (read: \(readBack ?? "nil"))")
            } else {
                report.append("\(key)  REMOVED")
            }
        }

        // Test current keys
        report.append("\n--- Current Keys ---")
        let currentKeys: [(String, Any)] = [
            ("groupName", "probe-test"),
            ("enabled", true),
            ("captureOnly", true),
            ("scale", 2.0),
        ]
        for (key, value) in currentKeys {
            if layer.responds(to: NSSelectorFromString(key))
                || layer.responds(to: NSSelectorFromString("is\(key.prefix(1).uppercased())\(key.dropFirst())"))
            {
                layer.setValue(value, forKey: key)
                let readBack = layer.value(forKey: key)
                report.append("\(key) = \(value)  OK (read: \(readBack ?? "nil"))")
            } else {
                report.append("\(key)  NOT RECOGNIZED")
            }
        }

        // Test mt_* material methods
        report.append("\n--- Material Methods (mt_*) ---")
        let mtSelectors = [
            "mt_applyMaterialDescription:removingIfIdentity:",
            "mt_orderedFilterTypes",
            "mt_orderedFilterTypesBlurAtEnd",
        ]
        for sel in mtSelectors {
            let responds = layer.responds(to: NSSelectorFromString(sel))
                || cls.responds(to: NSSelectorFromString(sel))
            report.append("\(sel)  \(responds ? "RESPONDS" : "NOT FOUND")")
        }

        // Test layerClass override
        let testView = BackdropProbeView()
        testView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let actualClass = String(cString: class_getName(type(of: testView.layer)))
        report.append("\n--- Layer Override ---")
        report.append("layerClass override → \(actualClass)")

        // Read default values
        report.append("\n--- Default Values ---")
        for key in ["enabled", "captureOnly", "scale", "groupName", "updateRate"] {
            if layer.responds(to: NSSelectorFromString(key))
                || layer.responds(to: NSSelectorFromString("is\(key.prefix(1).uppercased())\(key.dropFirst())"))
            {
                let val = layer.value(forKey: key)
                report.append("\(key) default = \(val ?? "nil")")
            }
        }

        return report.joined(separator: "\n")
    }

    // MARK: - Export
    //
    // ⚠️ DEVELOPER-ONLY TARGET — DO NOT ARCHIVE FOR APP STORE DISTRIBUTION.
    //
    // The JSON dump enumerates iOS private API surface (class names, selector
    // tables, ivar offsets). Combined with device identity (`hw.machine` +
    // `systemVersion`) this artifact is App-Store-prohibited content. It is
    // also a privacy surface if the probe is sideloaded onto a device the user
    // doesn't own.
    //
    // Mitigations:
    //  - `UIDevice.current.name` (often "Alex's iPhone") is STRIPPED.
    //  - Export is gated behind `#if DEBUG` so release builds of the probe
    //    cannot produce the JSON.
    //  - The on-disk artifact is tagged `.completeFileProtection` so it is
    //    unreadable while the device is locked, including by iCloud backup.

    func exportJSON() -> URL? {
        #if DEBUG
            let report: [String: Any] = [
                // Intentionally omitting UIDevice.current.name (may contain PII).
                "systemName": UIDevice.current.systemName,
                "systemVersion": UIDevice.current.systemVersion,
                "model": deviceModel(),
                "scanDate": ISO8601DateFormatter().string(from: Date()),
                "totalCAClasses": totalCAClasses,
                "totalUnderscoreClasses": totalUnderscoreClasses,
                "criticalAPIs": criticalAPIs.map { api in
                    ["name": api.name, "exists": api.exists, "detail": api.detail] as [String: Any]
                },
                "backdropLiveTest": backdropLiveTest,
                "classes": classDetails,
                "underscoreClasses": underscoreClassDetails,
            ]

            guard JSONSerialization.isValidJSONObject(report),
                  let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            else {
                return nil
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("ca-probe-v2-\(UIDevice.current.systemVersion).json")

            do {
                try data.write(to: url, options: [.atomic, .completeFileProtection])
                exportedFilePath = url.path
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("CA PROBE EXPORT: \(url.path)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                return url
            } catch {
                print("Export failed: \(error)")
                return nil
            }
        #else
            print("CA PROBE EXPORT: disabled in non-DEBUG builds (developer-only).")
            return nil
        #endif
    }

    private func deviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(decoding: machine.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self)
    }
}

private final class BackdropProbeView: UIView {
    override class var layerClass: AnyClass {
        NSClassFromString("CABackdropLayer") ?? CALayer.self
    }
}

// MARK: - App

@main
struct CAPrivateAPIProbeApp: App {
    var body: some Scene {
        WindowGroup {
            ProbeRootView()
        }
    }
}

// MARK: - Views

struct ProbeRootView: View {
    @StateObject private var viewModel = CAProbeViewModel()
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationView {
            List {
                // Actions
                Section {
                    Button(viewModel.isScanning ? "Scanning..." : "Run Full Scan") {
                        viewModel.scan()
                    }
                    .disabled(viewModel.isScanning)
                    .font(.headline)

                    if !viewModel.classDetails.isEmpty {
                        Button("Export JSON") {
                            if let url = viewModel.exportJSON() {
                                exportURL = url
                                showShareSheet = true
                            }
                        }
                        .font(.headline)
                    }
                }

                if let path = viewModel.exportedFilePath {
                    Section("Exported To") {
                        Text(path)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                // Critical APIs
                if !viewModel.criticalAPIs.isEmpty {
                    Section("AemiSDR Critical APIs") {
                        ForEach(viewModel.criticalAPIs) { api in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: api.exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(api.exists ? .green : .red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(api.name)
                                        .font(.system(.body, design: .monospaced, weight: .medium))
                                    Text(api.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Backdrop live test
                if viewModel.backdropLiveTest != "Not tested" {
                    Section("CABackdropLayer Live Test") {
                        Text(viewModel.backdropLiveTest)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                // Underscore classes
                if !viewModel.underscoreClassDetails.isEmpty {
                    Section("_UI* / _CA* Private Classes (\(viewModel.totalUnderscoreClasses))") {
                        ForEach(Array(viewModel.underscoreClassDetails.enumerated()), id: \.offset) { _, detail in
                            ClassDetailRow(detail: detail)
                        }
                    }
                }

                // All CA* classes
                if !viewModel.classDetails.isEmpty {
                    let layers = viewModel.classDetails.filter { isLayerSubclass($0) }
                    let others = viewModel.classDetails.filter { !isLayerSubclass($0) }

                    Section("CA* Layer Subclasses (\(layers.count) of \(viewModel.totalCAClasses))") {
                        ForEach(Array(layers.enumerated()), id: \.offset) { _, detail in
                            ClassDetailRow(detail: detail)
                        }
                    }

                    Section("Other CA* Classes (\(others.count))") {
                        ForEach(Array(others.enumerated()), id: \.offset) { _, detail in
                            ClassDetailRow(detail: detail)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("CA API Probe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    VStack(alignment: .trailing) {
                        Text(UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
                            .font(.caption2)
                        Text(viewModel.totalCAClasses > 0 ? "\(viewModel.totalCAClasses) CA* + \(viewModel.totalUnderscoreClasses) _*" : "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }

    private func isLayerSubclass(_ detail: [String: Any]) -> Bool {
        guard let chain = detail["superclassChain"] as? [String] else { return false }
        return chain.contains("CALayer")
    }
}

// MARK: - Class Detail Row

struct ClassDetailRow: View {
    let detail: [String: Any]
    @State private var expanded = false

    private var name: String { detail["name"] as? String ?? "?" }
    private var superclass: String? { detail["superclass"] as? String }
    private var properties: [[String: Any]] { detail["properties"] as? [[String: Any]] ?? [] }
    private var instanceMethods: [[String: Any]] { detail["instanceMethods"] as? [[String: Any]] ?? [] }
    private var classMethods: [[String: Any]] { detail["classMethods"] as? [[String: Any]] ?? [] }
    private var protocols: [String] { detail["protocols"] as? [String] ?? [] }
    private var ivars: [[String: Any]] { detail["ivars"] as? [[String: Any]] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { expanded.toggle() } label: {
                HStack {
                    Text(name)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let sup = superclass, sup != "NSObject" {
                        Text(": \(sup)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        badge("\(properties.count)p", .blue)
                        badge("\(instanceMethods.count)m", .purple)
                        if !ivars.isEmpty { badge("\(ivars.count)iv", .orange) }
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                // Protocols
                if !protocols.isEmpty {
                    Text("Protocols: \(protocols.joined(separator: ", "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                // Properties
                if !properties.isEmpty {
                    DisclosureGroup("Properties (\(properties.count))") {
                        ForEach(Array(properties.enumerated()), id: \.offset) { _, prop in
                            propertyRow(prop)
                        }
                    }
                    .font(.caption)
                }

                // Instance methods
                if !instanceMethods.isEmpty {
                    DisclosureGroup("Instance Methods (\(instanceMethods.count))") {
                        ForEach(Array(instanceMethods.enumerated()), id: \.offset) { _, meth in
                            methodRow(meth)
                        }
                    }
                    .font(.caption)
                }

                // Class methods
                if !classMethods.isEmpty {
                    DisclosureGroup("Class Methods (\(classMethods.count))") {
                        ForEach(Array(classMethods.enumerated()), id: \.offset) { _, meth in
                            methodRow(meth)
                        }
                    }
                    .font(.caption)
                }

                // Ivars
                if !ivars.isEmpty {
                    DisclosureGroup("Ivars (\(ivars.count))") {
                        ForEach(Array(ivars.enumerated()), id: \.offset) { _, ivar in
                            ivarRow(ivar)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func propertyRow(_ prop: [String: Any]) -> some View {
        let propName = prop["name"] as? String ?? "?"
        let type = prop["type"] as? String ?? "?"
        let ro = (prop["readonly"] as? Bool) == true
        return HStack(spacing: 4) {
            if ro {
                Text("RO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            Text(propName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            Spacer()
            Text(type)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func methodRow(_ meth: [String: Any]) -> some View {
        let sel = meth["selector"] as? String ?? "?"
        return Text(sel)
            .font(.system(size: 11, design: .monospaced))
            .lineLimit(1)
    }

    private func ivarRow(_ ivar: [String: Any]) -> some View {
        let ivarName = ivar["name"] as? String ?? "?"
        let type = ivar["typeEncoding"] as? String ?? "?"
        return HStack {
            Text(ivarName)
                .font(.system(size: 11, design: .monospaced))
            Spacer()
            Text(type)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
