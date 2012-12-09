//
//  HPAppDelegate.m
//  HPSocialNetworkManager
//
//  Created by Sarp Erdag on 12/3/12.
//  Copyright (c) 2012 Hipo. All rights reserved.
//

#import "HPAccountManager.h"
#import "HPAppDelegate.h"
#import "HPViewController.h"


static NSString * const HPFacebookAppID = @"261143290677780";
static NSString * const HPTwitterConsumerKey = @"53S2OYAd5r2wV1jbW5Dg";
static NSString * const HPTwitterConsumerSecret = @"pzxUp9Kh9nph0VnoJBzaZh7oo2scVl94xvqtaXagL0";


@implementation HPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[HPAccountManager sharedManager] setupWithFacebookAppID:HPFacebookAppID
                                      facebookAppPermissions:@[@"email", @"user_location", @"user_about_me"]
                                          twitterConsumerKey:HPTwitterConsumerKey
                                       twitterConsumerSecret:HPTwitterConsumerSecret];
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.viewController = [[[HPViewController alloc] initWithNibName:@"HPViewController" bundle:nil] autorelease];
    self.window.rootViewController = self.viewController;
    
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)dealloc {
    [_window release], _window = nil;
    [_viewController release], _viewController = nil;
    
    [super dealloc];
}

#pragma mark - URL handling

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [[HPAccountManager sharedManager] handleOpenURL:url];
}

@end
