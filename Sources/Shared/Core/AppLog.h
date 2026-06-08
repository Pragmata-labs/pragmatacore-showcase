// AppLog.h – ObjC/C++ logging macro; no-op in Release (when DEBUG is not defined).
// Use: APP_LOG("Tag", "format %@", arg);  or  APP_LOG("Tag", "message");
// Add to .mm: #import "AppLog.h"

#import <Foundation/Foundation.h>

#if DEBUG
#define APP_LOG(tag, fmt, ...) NSLog(@"[%s] " fmt, (tag), ##__VA_ARGS__)
#else
#define APP_LOG(tag, fmt, ...) do { (void)(tag); } while(0)
#endif
