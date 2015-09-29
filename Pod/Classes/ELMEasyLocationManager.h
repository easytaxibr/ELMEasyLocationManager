//
//  ELMEasyLocationManager.h
//  Pods
//
//  Created by Paulo Mendes on 9/29/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSUInteger, ELMGPSStatus) {
    ELMGPSStatusPending,
    ELMGPSStatusGranted,
    ELMGPSStatusDenied,
};

typedef void (^ELMBlockCompletion)(CLLocation *location);
typedef void (^ELMLocationBlockType)(CLLocation *location, NSError *error);

@protocol ELMGeolocationManagerDelegate <NSObject>

@optional
- (void)gpsAuthorizationStatusDidChange:(CLAuthorizationStatus)status;

@end


@interface ELMEasyLocationManager : NSObject


@property (nonatomic, weak) id<ELMGeolocationManagerDelegate> delegate;

+ (instancetype)sharedManager;
- (void)geolocationWithGPS:(ELMBlockCompletion)callback;

@end
