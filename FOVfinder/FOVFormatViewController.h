//
//  FOVFormatViewController.h
//  FOVfinder
//
//  Created by Tim Gleue on 05.11.15.
//  Copyright © 2015 Tim Gleue • interactive software. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const FOVFormatViewControllerFormatChanged;

@interface FOVFormatViewController : UITableViewController

@property (nonatomic, strong) NSString *videoFormat;

@end
