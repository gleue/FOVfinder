//
//  FOVGravityViewController.m
//  FOVfinder
//
//  Created by Tim Gleue on 25.03.14.
//  Copyright (c) 2015 Tim Gleue ( http://gleue-interactive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "FOVGravityViewController.h"

NSString * const FOVGravityViewControllerGravityChanged = @"FOVGravityViewControllerGravityChanged";

@interface FOVGravityViewController ()

@end

@implementation FOVGravityViewController

- (void)viewDidLoad {

    [super viewDidLoad];
    
    for (NSInteger row = 0; row < [self.tableView numberOfRowsInSection:0]; row++) {
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        
        NSString *videoGravity = [self videoGravityFromTextLabel:cell.textLabel];
        
        cell.accessoryType = [videoGravity isEqualToString:self.videoGravity] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    for (NSInteger row = 0; row < [tableView numberOfRowsInSection:0]; row++) {
        
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    cell.accessoryType = UITableViewCellAccessoryCheckmark;

    self.videoGravity = [self videoGravityFromTextLabel:cell.textLabel];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FOVGravityViewControllerGravityChanged object:self];
}

#pragma mark - Helpers

- (NSString *)videoGravityFromTextLabel:(UILabel *)label {
    
    return [@"AVLayerVideoGravity" stringByAppendingString:label.text];
}

@end
