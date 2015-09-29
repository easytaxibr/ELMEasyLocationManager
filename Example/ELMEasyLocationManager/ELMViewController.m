//
//  ELMViewController.m
//  ELMEasyLocationManager
//
//  Created by Paulo Mendes on 09/29/2015.
//  Copyright (c) 2015 Paulo Mendes. All rights reserved.
//

#import "ELMViewController.h"
#import "ELMEasyLocationManager.h"
@interface ELMViewController ()

@property (weak, nonatomic) IBOutlet UILabel *latLabel;
@property (weak, nonatomic) IBOutlet UILabel *lngLabel;

@end

@implementation ELMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)currentPositionButtonPressed:(id)sender {
    [[ELMEasyLocationManager sharedManager] geolocationWithGPS:^(CLLocation *location) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.latLabel.text = [NSString stringWithFormat:@"%@", @(location.coordinate.latitude)];
            self.lngLabel.text = [NSString stringWithFormat:@"%@", @(location.coordinate.longitude)];
        });
    }];
}

@end
