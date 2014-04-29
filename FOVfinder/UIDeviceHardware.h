//
//  UIDeviceHardware.h
//
//  Used to determine EXACT version of device software is running on.
//
//  Based on: https://gist.github.com/Jaybles/1323251
//

#import <Foundation/Foundation.h>

@interface UIDeviceHardware : NSObject 

+ (NSString *)platform;
+ (NSString *)platformString;

@end