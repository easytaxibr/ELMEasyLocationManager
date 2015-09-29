//
//  ELMEasyLocationManager.m
//  Pods
//
//  Created by Paulo Mendes on 9/29/15.
//
//

#import "ELMEasyLocationManager.h"

@interface ELMEasyLocationManager () <CLLocationManagerDelegate>

@property (nonatomic, strong) NSMutableArray *callbacks;
@property (nonatomic, assign) NSUInteger accuracy;
@property (nonatomic, strong) NSMutableArray *locationsByGps;
@property (nonatomic, strong) CLLocation *lastLocationReceived;
@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, strong) CLLocation *currentLocation;

@property (nonatomic, assign, getter=hasGpsLocationAssigned) BOOL gpsLocationAssign;

@end

static NSTimeInterval const kDefaultMTimeIntervalToAvoidCachedLocation = 10.0 * 60; // 5 minutes
static NSTimeInterval const kDefaultTimeoutForGps = 5.0;
static NSUInteger const kDefaultDesiredAccuracy = 70;
static NSString * const kLastReceivedLocationCached = @"ELM_lastReceivedLocation";

@implementation ELMEasyLocationManager

@synthesize lastLocationReceived = _lastLocationReceived;

+ (instancetype)sharedManager {
    static ELMEasyLocationManager * sharedManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.currentLocation = [[CLLocation alloc] init];
        self.callbacks = [NSMutableArray array];
        self.accuracy = kDefaultDesiredAccuracy;
        self.locationsByGps = [NSMutableArray array];
    }
    return self;
}


- (void)geolocationWithGPS:(void (^)(CLLocation *location))callback {
    [self.callbacks addObject:[callback copy]];
    
    switch ([self gpsStatus]) {
        case ELMGPSStatusPending:
            [self askForGpsPermission];
            break;
        case ELMGPSStatusGranted:
            [self startUpdateGps];
            break;
        case ELMGPSStatusDenied:
            break;
    }
}

#pragma mark - Private Methods

- (void)askForGpsPermission {
    // iOS 8+ is necessary to call requestWhenInUseAuthorization.
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        [self.locationManager startUpdatingLocation];
    }
}

- (ELMGPSStatus)gpsStatus {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    ELMGPSStatus gpsStatus = ELMGPSStatusDenied;
    
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            gpsStatus = ELMGPSStatusPending;
            break;
        case kCLAuthorizationStatusDenied:
            gpsStatus = ELMGPSStatusDenied;
            break;
        default:
            gpsStatus = ELMGPSStatusGranted;
            break;
    }
    
    return gpsStatus;
}

- (BOOL)isLocation:(CLLocation *)currentLocation withinTheRadiusOfLocation:(CLLocation *)givenLocation {
    
    CLLocationDistance distance = [currentLocation distanceFromLocation:givenLocation];
    
    if (distance > givenLocation.horizontalAccuracy) {
        return NO;
    } else {
        return YES;
    }
}

- (CLLocation *)bestLocationAfterTimeout {
    NSSortDescriptor *sortAccuracy = [NSSortDescriptor sortDescriptorWithKey:@"horizontalAccuracy" ascending:YES];
    NSSortDescriptor *sortTimestamp = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    [self.locationsByGps sortUsingDescriptors:@[ sortAccuracy, sortTimestamp ]];
    CLLocation *bestEffortLocation = [self.locationsByGps firstObject];
    CLLocation *returnedLocation;
    CLLocation *lastLocationReceived = self.lastLocationReceived;
    
    
    if ([[NSDate date] timeIntervalSinceDate:lastLocationReceived.timestamp] < kDefaultMTimeIntervalToAvoidCachedLocation &&
        [self isLocation:lastLocationReceived withinTheRadiusOfLocation:bestEffortLocation]) {
        NSLog(@"======= Cached Location: %@ =======", self.lastLocationReceived);
        returnedLocation = lastLocationReceived;
    } else {
        NSLog(@"======= Best Effort Location: %@ =======", self.lastLocationReceived);
        returnedLocation = bestEffortLocation;
    }
    
    return returnedLocation;
}

- (void)gpsTimeout {
    if (![self hasGpsLocationAssigned]) {
        NSLog(@"======= Setting Location by Timeout =======");
        [self selectLocation:[self bestLocationAfterTimeout]];
    }
}

- (void)startUpdateGps {
    self.gpsLocationAssign = NO;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    
    if (self.locationManager.location) {
        self.lastLocationReceived = self.locationManager.location;
    }
    
    [self.locationManager startUpdatingLocation];
    [self performSelector:@selector(gpsTimeout) withObject:nil afterDelay:kDefaultTimeoutForGps];
}

- (void)selectLocation:(CLLocation *)location {
    self.gpsLocationAssign = YES;
    [self.locationManager stopUpdatingLocation];
    [self.locationsByGps removeAllObjects];
    
    NSLog(@"======= Setting Geolocation: %@ =======", location);
    self.lastLocationReceived = location;
    self.currentLocation = location;
    
    NSArray *callbacks = [self.callbacks copy];
    for (ELMLocationBlockType block in callbacks) {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(self.currentLocation, nil);
        });
    }
    
    [self.callbacks removeAllObjects];
}

#pragma mark - getter and setter

- (CLLocation *)lastLocationReceived {
    NSDictionary *lastLocation = [[NSUserDefaults standardUserDefaults] objectForKey:kLastReceivedLocationCached];
    
    if (lastLocation) {
        CLLocationCoordinate2D coordinate = {[lastLocation[@"lat"] doubleValue], [lastLocation[@"lng"] doubleValue]};
        CLLocation *location = [[CLLocation alloc] initWithCoordinate:coordinate
                                                             altitude:0
                                                   horizontalAccuracy:[lastLocation[@"accuracy"] doubleValue]
                                                     verticalAccuracy:0
                                                            timestamp:lastLocation[@"timestamp"]];
        return location;
    }
    
    return nil;
}

- (void)setLastLocationReceived:(CLLocation *)location {
    CLLocation *lastLocationReceivedCached = self.lastLocationReceived;
    
    if ((location.horizontalAccuracy <= lastLocationReceivedCached.horizontalAccuracy &&
         [location.timestamp compare:lastLocationReceivedCached.timestamp] == NSOrderedDescending) ||
        !lastLocationReceivedCached) {
        
        _lastLocationReceived = location;
        if (location) {
            NSDictionary *lastLocation = @{@"lat" : @(location.coordinate.latitude),
                                           @"lng" : @(location.coordinate.longitude),
                                           @"timestamp" : location.timestamp,
                                           @"accuracy" : @(location.horizontalAccuracy)};
            
            [[NSUserDefaults standardUserDefaults] setObject:lastLocation forKey:kLastReceivedLocationCached];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

#pragma mark - CLLOcationManager Delegate Implementation

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"%@", error);
    NSArray *callbacks = [self.callbacks copy];
    for (ELMLocationBlockType block in callbacks) {
        block(nil, error);
        [self.callbacks removeObject:block];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (self.delegate && [self.delegate respondsToSelector:@selector(gpsAuthorizationStatusDidChange:)]) {
        [self.delegate gpsAuthorizationStatusDidChange:status];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    CLLocation *location = [locations firstObject];
    if ([[NSDate date] timeIntervalSinceDate:location.timestamp] > kDefaultMTimeIntervalToAvoidCachedLocation) {
        return;
    }
    
    [self.locationsByGps addObject:location];
    if (location.horizontalAccuracy <= kDefaultDesiredAccuracy) {
        [self selectLocation:location];
    }
}


@end
