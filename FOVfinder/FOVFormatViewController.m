//
//  FOVFormatViewController.m
//  FOVfinder
//
//  Created by Tim Gleue on 05.11.15.
//  Copyright © 2015 Tim Gleue • interactive software. All rights reserved.
//

#import "FOVFormatViewController.h"

NSString * const FOVFormatViewControllerFormatChanged = @"FOVFormatViewControllerFormatChanged";

@interface FOVFormatViewController ()

@end

@implementation FOVFormatViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    for (NSInteger row = 0; row < [self.tableView numberOfRowsInSection:0]; row++) {
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        
        NSString *videoFormat = [self videoFormatFromTextLabel:cell.textLabel];
        
        cell.accessoryType = [videoFormat isEqualToString:self.videoFormat] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
}

#pragma mark - UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    for (NSInteger row = 0; row < [tableView numberOfRowsInSection:0]; row++) {
        
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    self.videoFormat = [self videoFormatFromTextLabel:cell.textLabel];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FOVFormatViewControllerFormatChanged object:self];
}

#pragma mark - Helpers

- (NSString *)videoFormatFromTextLabel:(UILabel *)label {
    
    return [@"AVCaptureSessionPreset" stringByAppendingString:label.text];
}

@end
