//
//  ObjCExceptionCatcher.m
//  Daycatcher
//
//  Utility for catching Objective-C exceptions that Swift cannot catch.
//

#import "ObjCExceptionCatcher.h"

NSString *const ObjCExceptionCatcherErrorDomain = @"ObjCExceptionCatcherErrorDomain";

@implementation ObjCExceptionCatcher

+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock {
    return [self tryBlock:tryBlock error:nil];
}

+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock error:(NSError * _Nullable * _Nullable)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:ObjCExceptionCatcherErrorDomain
                                         code:-1
                                     userInfo:@{
                NSLocalizedDescriptionKey: exception.reason ?: @"Unknown Objective-C exception",
                @"ExceptionName": exception.name ?: @"Unknown",
                @"ExceptionReason": exception.reason ?: @"Unknown",
                @"ExceptionUserInfo": exception.userInfo ?: @{}
            }];
        }
        return NO;
    }
}

@end
