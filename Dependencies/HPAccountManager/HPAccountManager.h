//
//  HPAccountManager.h
//  HPSocialNetworkManager
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <FacebookSDK/FacebookSDK.h>
#import <Twitter/Twitter.h>

#import "HPAccount.h"


typedef void (^HPAccountAuthHandler)(HPAccount *authenticatedAccount, NSDictionary *profileInfo, NSError *error);

typedef enum {
    HPAccountManagerErrorNone = 0,
    HPAccountManagerErrorUnknownServiceType = 101,
    HPAccountManagerErrorAuthenticationInProcess = 102,
    HPAccountManagerErrorAuthenticationFailed = 103,
    HPAccountManagerErrorNoAccountFound = 104,
    HPAccountManagerErrorCancelled = 105,
} HPAccountManagerError;


@class TWAPIManager;

@interface HPAccountManager : NSObject <UIActionSheetDelegate> {
@private
    FBSession *_facebookSession;
    TWAPIManager *_twitterManager;

    ACAccount *_twitterAccount;
    ACAccountStore *_accountStore;
    
    NSString *_facebookAppID;
    NSArray *_facebookPermissions;
    
    HPAccountAuthHandler _authHandler;
}

@property (nonatomic, readonly) NSString *twitterUsername;
@property (nonatomic, readonly) NSString *twitterToken;
@property (nonatomic, readonly) NSString *twitterTokenSecret;
@property (nonatomic, readonly) NSString *facebookToken;

+ (HPAccountManager *)sharedManager;

- (void)setupWithFacebookAppID:(NSString *)facebookAppID
        facebookAppPermissions:(NSArray *)facebookAppPermissions
            twitterConsumerKey:(NSString *)twitterConsumerKey
         twitterConsumerSecret:(NSString *)twitterConsumerSecret;

- (BOOL)hasAuthenticatedAccountOfType:(HPAccountType)accountType;

- (void)authenticateAccountOfType:(HPAccountType)accountType
                      withHandler:(HPAccountAuthHandler)handler;

- (BOOL)handleOpenURL:(NSURL *)url;

@end
