#import <Foundation/Foundation.h>

/// Enumerates all ObjC runtime classes whose name starts with a given prefix.
/// Returns sorted class names as an NSArray of NSString.
/// Runs in pure ObjC to avoid Swift metadata realization crashes.
NSArray<NSString *> *_Nonnull enumerateClassNames(NSString *_Nonnull prefix);

/// Introspects a single class via the ObjC runtime.
/// Returns a dictionary with keys: superclass, properties, instanceMethods,
/// classMethods, protocols, ivars. All values are strings or arrays of strings/dicts.
/// Runs in pure ObjC for safety — some classes crash if introspected from Swift.
NSDictionary<NSString *, id> *_Nullable probeClassDetails(NSString *_Nonnull className);
