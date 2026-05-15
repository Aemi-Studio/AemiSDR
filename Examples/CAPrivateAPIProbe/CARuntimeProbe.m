#import "CARuntimeProbe.h"
#import <objc/runtime.h>

NSArray<NSString *> *enumerateClassNames(NSString *prefix) {
    const char *cPrefix = [prefix UTF8String];
    size_t prefixLen = strlen(cPrefix);

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) return @[];

    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (name && strncmp(name, cPrefix, prefixLen) == 0) {
            [result addObject:[NSString stringWithUTF8String:name]];
        }
    }
    free(classes);

    [result sortUsingSelector:@selector(compare:)];
    return result;
}

NSDictionary<NSString *, id> *probeClassDetails(NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return nil;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"name"] = className;

    // Superclass chain
    Class super_ = class_getSuperclass(cls);
    if (super_) {
        info[@"superclass"] = [NSString stringWithUTF8String:class_getName(super_)];
    }

    // Full superclass chain
    NSMutableArray *chain = [NSMutableArray array];
    Class cur = super_;
    while (cur) {
        [chain addObject:[NSString stringWithUTF8String:class_getName(cur)]];
        cur = class_getSuperclass(cur);
    }
    info[@"superclassChain"] = chain;

    // Properties (declared on this class, not inherited)
    {
        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &propCount);
        NSMutableArray *propList = [NSMutableArray arrayWithCapacity:propCount];
        if (props) {
            for (unsigned int i = 0; i < propCount; i++) {
                const char *pName = property_getName(props[i]);
                const char *pAttrs = property_getAttributes(props[i]);
                NSMutableDictionary *p = [NSMutableDictionary dictionary];
                if (pName) p[@"name"] = [NSString stringWithUTF8String:pName];
                if (pAttrs) p[@"attributes"] = [NSString stringWithUTF8String:pAttrs];

                // Parse type encoding from attributes
                if (pAttrs) {
                    NSString *attrs = [NSString stringWithUTF8String:pAttrs];
                    // First component after 'T' is the type
                    NSArray *parts = [attrs componentsSeparatedByString:@","];
                    if (parts.count > 0) {
                        NSString *typeStr = parts[0];
                        if (typeStr.length > 1) {
                            p[@"type"] = [typeStr substringFromIndex:1];
                        }
                    }
                    p[@"readonly"] = @([attrs containsString:@",R"]);
                    p[@"nonatomic"] = @([attrs containsString:@",N"]);
                    p[@"weak"] = @([attrs containsString:@",W"]);
                    p[@"dynamic"] = @([attrs containsString:@",D"]);
                }

                [propList addObject:p];
            }
            free(props);
        }
        info[@"properties"] = propList;
    }

    // Instance methods (declared on this class, not inherited)
    {
        unsigned int methCount = 0;
        Method *meths = class_copyMethodList(cls, &methCount);
        NSMutableArray *methList = [NSMutableArray arrayWithCapacity:methCount];
        if (meths) {
            for (unsigned int i = 0; i < methCount; i++) {
                SEL sel = method_getName(meths[i]);
                const char *typeEnc = method_getTypeEncoding(meths[i]);
                NSMutableDictionary *m = [NSMutableDictionary dictionary];
                m[@"selector"] = NSStringFromSelector(sel);
                if (typeEnc) m[@"typeEncoding"] = [NSString stringWithUTF8String:typeEnc];
                [methList addObject:m];
            }
            free(meths);
        }
        // Sort by selector name
        [methList sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"selector"] compare:b[@"selector"]];
        }];
        info[@"instanceMethods"] = methList;
    }

    // Class methods
    {
        Class metaCls = object_getClass(cls);
        unsigned int methCount = 0;
        Method *meths = class_copyMethodList(metaCls, &methCount);
        NSMutableArray *methList = [NSMutableArray arrayWithCapacity:methCount];
        if (meths) {
            for (unsigned int i = 0; i < methCount; i++) {
                SEL sel = method_getName(meths[i]);
                const char *typeEnc = method_getTypeEncoding(meths[i]);
                NSMutableDictionary *m = [NSMutableDictionary dictionary];
                m[@"selector"] = NSStringFromSelector(sel);
                if (typeEnc) m[@"typeEncoding"] = [NSString stringWithUTF8String:typeEnc];
                [methList addObject:m];
            }
            free(meths);
        }
        [methList sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"selector"] compare:b[@"selector"]];
        }];
        info[@"classMethods"] = methList;
    }

    // Protocols
    {
        unsigned int protoCount = 0;
        Protocol * __unsafe_unretained *protos = class_copyProtocolList(cls, &protoCount);
        NSMutableArray *protoList = [NSMutableArray arrayWithCapacity:protoCount];
        if (protos) {
            for (unsigned int i = 0; i < protoCount; i++) {
                const char *pName = protocol_getName(protos[i]);
                if (pName) [protoList addObject:[NSString stringWithUTF8String:pName]];
            }
            free(protos);
        }
        [protoList sortUsingSelector:@selector(compare:)];
        info[@"protocols"] = protoList;
    }

    // Ivars
    {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        NSMutableArray *ivarList = [NSMutableArray arrayWithCapacity:ivarCount];
        if (ivars) {
            for (unsigned int i = 0; i < ivarCount; i++) {
                const char *iName = ivar_getName(ivars[i]);
                const char *iType = ivar_getTypeEncoding(ivars[i]);
                NSMutableDictionary *iv = [NSMutableDictionary dictionary];
                if (iName) iv[@"name"] = [NSString stringWithUTF8String:iName];
                if (iType) iv[@"typeEncoding"] = [NSString stringWithUTF8String:iType];
                iv[@"offset"] = @(ivar_getOffset(ivars[i]));
                [ivarList addObject:iv];
            }
            free(ivars);
        }
        info[@"ivars"] = ivarList;
    }

    return info;
}
