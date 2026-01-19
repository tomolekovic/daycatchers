//
//  ObjCExceptionCatcher.h
//  Daycatcher
//
//  Utility for catching Objective-C exceptions that Swift cannot catch.
//  This is essential for handling Core Data fault fulfillment failures
//  which throw NSObjectInaccessibleException.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

/// Executes a block and catches any Objective-C exceptions.
/// @param tryBlock The block to execute that might throw an ObjC exception.
/// @return YES if the block executed without throwing, NO if an exception was caught.
+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock;

/// Executes a block and catches any Objective-C exceptions, returning the exception if one occurred.
/// @param tryBlock The block to execute that might throw an ObjC exception.
/// @param error On return, if an exception was thrown, contains an NSError describing the exception.
/// @return YES if the block executed without throwing, NO if an exception was caught.
+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
