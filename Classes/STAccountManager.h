//
//  STAccountManager.h
//  Strum
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <FacebookSDK/FacebookSDK.h>
#import <Twitter/Twitter.h>

#import "STAccount.h"


typedef void (^STAccountAuthHandler)(STAccount *authenticatedAccount, NSDictionary *profileInfo, NSError *error);

typedef enum {
    STAccountManagerErrorNone = 0,
    STAccountManagerErrorUnknownServiceType = 101,
    STAccountManagerErrorAuthenticationInProcess = 102,
    STAccountManagerErrorAuthenticationFailed = 103,
    STAccountManagerErrorNoAccountFound = 104,
    STAccountManagerErrorCancelled = 105,
} STAccountManagerError;


@class TWAPIManager;

@interface STAccountManager : NSObject <UIActionSheetDelegate> {
@private
    FBSession *_facebookSession;
    TWAPIManager *_twitterManager;

    ACAccount *_twitterAccount;
    ACAccountStore *_accountStore;
    
    STAccountAuthHandler _authHandler;
}

@property (nonatomic, readonly) NSString *twitterToken;
@property (nonatomic, readonly) NSString *twitterTokenSecret;
@property (nonatomic, readonly) NSString *facebookToken;

+ (STAccountManager *)sharedManager;

- (void)setupWithLaunchOptions:(NSDictionary *)launchOptions;

- (BOOL)hasAuthenticatedAccountOfType:(STAccountType)accountType;

- (void)authenticateAccountOfType:(STAccountType)accountType
                      withHandler:(STAccountAuthHandler)handler;

- (BOOL)handleOpenURL:(NSURL *)url;

@end
