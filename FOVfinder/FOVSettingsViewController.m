//
//  FOVSettingsViewController.m
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

#import "FOVSettingsViewController.h"
#import "FOVGravityViewController.h"

@interface FOVSettingsViewController () {
    
    NSInteger _currentRow;
}

@property (weak, nonatomic) IBOutlet UITableViewCell *gravityCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *distanceCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *heightCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *sizeCell;

@property (weak, nonatomic) UIPickerView *distancePicker;
@property (weak, nonatomic) UIPickerView *heightPicker;
@property (weak, nonatomic) UIPickerView *sizePicker;

@end

@implementation FOVSettingsViewController

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
}

- (void)viewDidLoad {

    [super viewDidLoad];
    
    _currentRow = -1;
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    
    [self updateCells];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gravityChanged:) name:FOVGravityViewControllerGravityChanged object:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"OpenGravitySelection"]) {
        
        FOVGravityViewController *controller = segue.destinationViewController;
        
        controller.videoGravity = self.videoGravity;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 1 && indexPath.row != _currentRow) {

        _currentRow = indexPath.row;

        UIPickerView *picker = [[UIPickerView alloc] init];
        
        picker.dataSource = self;
        picker.delegate = self;
        
        NSInteger row = 0;

        switch (_currentRow) {

            case 0:

                self.distancePicker = picker;
                row = [self pickerView:picker rowForValue:@(self.overlayDistance)];
                break;
                
            case 1:
                
                self.heightPicker = picker;
                row = [self pickerView:picker rowForValue:@(self.overlayHeight)];
                break;
                
            case 2:
                
                self.sizePicker = picker;
                row = [self pickerView:picker rowForValue:[NSValue valueWithCGSize:self.overlaySize]];
                break;
                
            default:
                break;
        }
        
        [picker selectRow:row inComponent:0 animated:NO];

        UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
        
        field.inputView = picker;
        field.delegate = self;
        
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        
        [cell insertSubview:field belowSubview:cell.contentView];

        [field becomeFirstResponder];
    }
}

#pragma mark - TextField delegate

- (void)textFieldDidEndEditing:(UITextField *)textField {

    [textField removeFromSuperview];
}

#pragma mark - Picker data source

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {

    return 1;
}

static CGFloat distances[] = { 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0, 180.0, 190.0, 200.0 };
static CGFloat heights[] = { 0.0, -10.0, -20.0, -30.0, -40.0, -50.0, -60.0, -70.0, -80.0, -90.0, -100.0, -110.0, -120.0, -130.0, -140.0, -150.0, -200.0 };
static CGSize sizes[] = { { 10.0, 15.0 }, { 21.0, 29.7 }, { 100.0, 100.0 } };

- (NSInteger)pickerView:(UIPickerView *)pickerView rowForValue:(id)value {

    if (pickerView == self.distancePicker) {

        CGFloat distance = [(NSNumber *)value doubleValue];

        for (NSInteger idx = 0; idx < sizeof(distances) / sizeof(distances[0]); idx++) {

            if (distances[idx] == distance) return idx;
        }
        
    } else if (pickerView == self.heightPicker) {
        
        CGFloat height = [(NSNumber *)value doubleValue];
        
        for (NSInteger idx = 0; idx < sizeof(heights) / sizeof(heights[0]); idx++) {
            
            if (heights[idx] == height) return idx;
        }
        
    } else if (pickerView == self.sizePicker) {
        
        CGSize size = [(NSValue *)value CGSizeValue];

        for (NSInteger idx = 0; idx < sizeof(sizes) / sizeof(sizes[0]); idx++) {
            
            if (CGSizeEqualToSize(sizes[idx], size)) return idx;
        }
    }
    
    return 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {

    if (pickerView == self.distancePicker) {
        
        return sizeof(distances) / sizeof(distances[0]);

    } else if (pickerView == self.heightPicker) {
        
        return sizeof(heights) / sizeof(heights[0]);
        
    } else if (pickerView == self.sizePicker) {
        
        return sizeof(sizes) / sizeof(sizes[0]);

    } else {

        return 0;
    }
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    if (pickerView == self.distancePicker) {
        
        NSString *dist = [NSNumberFormatter localizedStringFromNumber:@(distances[row]) numberStyle:NSNumberFormatterDecimalStyle];
        
        return [NSString stringWithFormat:@"%@cm", dist];
        
    } else if (pickerView == self.heightPicker) {
        
        NSString *height = [NSNumberFormatter localizedStringFromNumber:@(heights[row]) numberStyle:NSNumberFormatterDecimalStyle];
        
        return [NSString stringWithFormat:@"%@cm", height];
        
    } else if (pickerView == self.sizePicker) {
        
        NSString *width = [NSNumberFormatter localizedStringFromNumber:@(sizes[row].width) numberStyle:NSNumberFormatterDecimalStyle];
        NSString *height = [NSNumberFormatter localizedStringFromNumber:@(sizes[row].height) numberStyle:NSNumberFormatterDecimalStyle];
        
        return [NSString stringWithFormat:@"%@cm x %@cm", width, height];
        
    } else {
        
        return nil;
    }
}

#pragma mark - Picker delegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    if (pickerView == self.distancePicker) {

        self.overlayDistance = distances[row];
        
        [self updateDistanceCell];

    } else if (pickerView == self.heightPicker) {

        self.overlayHeight = heights[row];

        [self updateHeightCell];

    } else if (pickerView == self.sizePicker) {

        self.overlaySize = sizes[row];
        
        [self updateSizeCell];
    }
}

#pragma mark - Notification handlers

- (void)gravityChanged:(NSNotification *)notification {

    FOVGravityViewController *controller = notification.object;
    
    self.videoGravity = controller.videoGravity;

    [self updateGravityCell];
}

#pragma mark - Helpers

- (void)updateCells {

    [self updateGravityCell];
    [self updateDistanceCell];
    [self updateHeightCell];
    [self updateSizeCell];
}

- (void)updateGravityCell {

    if (self.videoGravity.length > 0) {
        
        self.gravityCell.detailTextLabel.text = [self.videoGravity substringFromIndex:19];

    } else {
        
        self.gravityCell.detailTextLabel.text = NSLocalizedString(@"undefined", nil);
    }
}

- (void)updateDistanceCell {
    
    NSString *dist = [NSNumberFormatter localizedStringFromNumber:@(self.overlayDistance) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.distanceCell.detailTextLabel.text = [NSString stringWithFormat:@"%@cm", dist];
}

- (void)updateHeightCell {

    NSString *height = [NSNumberFormatter localizedStringFromNumber:@(self.overlayHeight) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.heightCell.detailTextLabel.text = [NSString stringWithFormat:@"%@cm", height];
}

- (void)updateSizeCell {
    
    NSString *width = [NSNumberFormatter localizedStringFromNumber:@(self.overlaySize.width) numberStyle:NSNumberFormatterDecimalStyle];
    NSString *height = [NSNumberFormatter localizedStringFromNumber:@(self.overlaySize.height) numberStyle:NSNumberFormatterDecimalStyle];

    self.sizeCell.detailTextLabel.text = [NSString stringWithFormat:@"%@cm x %@cm", width, height];
}

@end
