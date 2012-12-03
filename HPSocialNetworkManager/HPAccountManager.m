//
//  STAccountManager.m
//  Strum
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

#import "TWAPIManager.h"

#import "HPAccountManager.h"
#import "HPAppDelegate.h"
//#import "STUser.h"


static NSString * const STFacebookAppID = @"303313163103377";
static NSString * const STTwitterConsumerKey = @"add9vW4qKN25vjDvmIDA";
static NSString * const STTwitterConsumerSecret = @"YaKWEsR03v6xP81dV53NXLRdKKEyKdahLazGgaqWKQ";
static NSString * const STAccountManagerErrorDomain = @"com.strum.Strum.authError";
static NSString * const STAccountManagerTwitterVerifyURL = @"http://api.twitter.com/1/account/verify_credentials.json";
static NSString * const STAccountManagerTwitterTokenKey = @"twitterToken";
static NSString * const STAccountManagerTwitterSecretKey = @"twitterSecret";


@interface HPAccountManager (Private)

- (void)authenticateFacebookAccount;
- (void)authenticateTwitterAccount;

- (void)checkSystemTwitterAccountsAgainstAccount:(HPAccount *)account;
- (void)generateTokenForTwitterAccount:(ACAccount *)twitterAccount;
- (void)fetchDetailsForTwitterAccount:(ACAccount *)twitterAccount;
- (void)fetchDetailsForFacebookAccount;

- (void)completeAuthProcessWithAccount:(HPAccount *)account
                           profileInfo:(NSDictionary *)profileInfo
                                 error:(HPAccountManagerError)error;

- (void)didReceiveApplicationDidBecomeActiveNotification:(NSNotification *)notification;
- (void)didReceiveApplicationWillTerminateNotification:(NSNotification *)notification;

@end


@implementation HPAccountManager

+ (HPAccountManager *)sharedManager {
    static HPAccountManager *_sharedManager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _sharedManager = [[HPAccountManager alloc] init];
    });
    
    return _sharedManager;
}

- (id)init {
    self = [super init];
    
    if (self) {
        [FBSession setDefaultAppID:STFacebookAppID];
        
        _authHandler = nil;
        _accountStore = [[ACAccountStore alloc] init];

        _facebookSession = [[FBSession alloc] initWithAppID:STFacebookAppID
                                                permissions:@[@"email", @"user_location",
                                                                @"publish_stream", @"user_about_me"]
                                            defaultAudience:FBSessionDefaultAudienceNone
                                            urlSchemeSuffix:nil
                                         tokenCacheStrategy:nil];
        
        _twitterManager = [[TWAPIManager alloc] init];
        
        [_twitterManager setConsumerKey:STTwitterConsumerKey];
        [_twitterManager setConsumerSecret:STTwitterConsumerSecret];

        /*
        if ([STUser hasAuthenticatedUser]) {
            STAccount *facebookAccount = [[STUser authenticatedUser]
                                          connectedAccountOfType:HPAccountTypeFacebook];
            
            if (facebookAccount != nil && [self hasAuthenticatedAccountOfType:HPAccountTypeFacebook]) {
                [self authenticateFacebookAccount];
            }

            STAccount *twitterAccount = [[STUser authenticatedUser]
                                         connectedAccountOfType:HPAccountTypeTwitter];
            
            if (twitterAccount != nil && self.twitterToken != nil && self.twitterTokenSecret != nil) {
                [self checkSystemTwitterAccountsAgainstAccount:twitterAccount];
            }
        }
        */
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveApplicationWillTerminateNotification:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:[UIApplication sharedApplication]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveApplicationDidBecomeActiveNotification:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:[UIApplication sharedApplication]];
    }
    
    return self;
}

- (void)dealloc {
    [_facebookSession release], _facebookSession = nil;
    [_authHandler release], _authHandler = nil;
    [_twitterAccount release], _twitterAccount = nil;
    [_accountStore release], _accountStore = nil;
    [_twitterManager release], _twitterManager = nil;
    
    [super dealloc];
}

#pragma mark - Setup

- (void)setupWithLaunchOptions:(NSDictionary *)launchOptions {
    
}

#pragma mark - Authentication check

- (BOOL)hasAuthenticatedAccountOfType:(HPAccountType)accountType {
    switch (accountType) {
        case HPAccountTypeFacebook: {
            return (_facebookSession.state == FBSessionStateCreatedTokenLoaded ||
                    _facebookSession.state == FBSessionStateOpen ||
                    _facebookSession.state == FBSessionStateOpenTokenExtended);
            break;
        }
        case HPAccountTypeTwitter: {
            return (_twitterAccount != nil);
            
            break;
        }
        default:
            break;
    }
    
    return NO;
}

#pragma mark - Authentication

- (void)authenticateAccountOfType:(HPAccountType)accountType
                      withHandler:(HPAccountAuthHandler)handler {
    if (accountType == HPAccountTypeUnknown) {
        handler(nil, nil, [NSError errorWithDomain:STAccountManagerErrorDomain
                                              code:HPAccountManagerErrorUnknownServiceType
                                          userInfo:nil]);
        
        return;
    }
    
    if (_authHandler != nil) {
        handler(nil, nil, [NSError errorWithDomain:STAccountManagerErrorDomain
                                              code:HPAccountManagerErrorAuthenticationInProcess
                                          userInfo:nil]);
        
        return;
    }
    
    _authHandler = [[handler autorelease] copy];
    
    switch (accountType) {
        case HPAccountTypeFacebook: {
            [self authenticateFacebookAccount];
            
            break;
        }
        case HPAccountTypeTwitter: {
            [self authenticateTwitterAccount];
            
            break;
        }
        default:
            break;
    }
}

#pragma mark - Facebook login

- (void)authenticateFacebookAccount {
    if ([_facebookSession isOpen] && [self hasAuthenticatedAccountOfType:HPAccountTypeFacebook]) {
        [self fetchDetailsForFacebookAccount];
        
        return;
    }
    
    [_facebookSession openWithCompletionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
        switch (status) {
            case FBSessionStateClosed:
                NSLog(@"STATUS: CLOSED");
                break;
            case FBSessionStateClosedLoginFailed:
                NSLog(@"STATUS: CLOSED LOGIN FAILED");
                break;
            case FBSessionStateCreated:
                NSLog(@"STATUS: CREATED");
                break;
            case FBSessionStateCreatedOpening:
                NSLog(@"STATUS: CREATED OPENING");
                break;
            case FBSessionStateCreatedTokenLoaded:
                NSLog(@"STATUS: CREATED TOKEN LOADING");
                break;
            case FBSessionStateOpen:
                NSLog(@"STATUS: OPEN");
                break;
            case FBSessionStateOpenTokenExtended:
                NSLog(@"STATUS: OPEN TOKEN EXTENDED");
                break;
            default:
                break;
        }
        NSLog(@">>> AUTH COMPLETE: %@ / %d / %@", session, status, error);
        if (_authHandler == nil) {
            NSLog(@"NO AUTH HANDLER: BAIL");
            return;
        }
        
        if (status != FBSessionStateOpen && status != FBSessionStateOpenTokenExtended) {
            NSLog(@"STATUS WRONG: BAIL");
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];
            
            return;
        }
        
        [FBSession setActiveSession:_facebookSession];

        [self fetchDetailsForFacebookAccount];
    }];
}

- (void)fetchDetailsForFacebookAccount {
    [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        NSLog(@">>> ME RESPONSE: %@ / %@", result, error);
        if (result != nil && error == nil) {
            HPAccount *account = [HPAccount accountWithType:HPAccountTypeFacebook
                                                 identifier:[result valueForKey:@"id"]];
            
            [self completeAuthProcessWithAccount:account
                                     profileInfo:result
                                           error:HPAccountManagerErrorNone];
        } else {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];
        }
    }];
}

#pragma mark - Twitter login

- (void)authenticateTwitterAccount {
    // Request access to Twitter accounts, once permission is given, check available accounts
    // If there is more than one, display picker interface, or if there is only one, move on
    // Once an account is selected, fetch profile by using the verify endpoint
    // Then call the authHandler block with the STAccount instance
    
    ACAccountType *twitterAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:
                                         ACAccountTypeIdentifierTwitter];
    
    if ([[_accountStore accountsWithAccountType:twitterAccountType] count] == 0) {
        [self completeAuthProcessWithAccount:nil
                                 profileInfo:nil
                                       error:HPAccountManagerErrorNoAccountFound];
        
        return;
    }
    
    ACAccountStoreRequestAccessCompletionHandler completionHandler = ^(BOOL granted, NSError *error) {
        if (!granted || error != nil) {
            NSLog(@"ACCESS REQUEST FAIL: %@", error);
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];
            
            return;
        }
        
        /*
        STAccount *twitterAccount = [[STUser authenticatedUser]
                                     connectedAccountOfType:HPAccountTypeTwitter];
        NSLog(@"EXISTING ACCOUNT: %@", twitterAccount);
         */
        //[self checkSystemTwitterAccountsAgainstAccount:twitterAccount];
    };
    
    if ([_accountStore respondsToSelector:@selector(requestAccessToAccountsWithType:options:completion:)]) {
        [_accountStore requestAccessToAccountsWithType:twitterAccountType
                                               options:nil
                                            completion:completionHandler];
    } else {
        [_accountStore requestAccessToAccountsWithType:twitterAccountType
                                 withCompletionHandler:completionHandler];
    }
}

- (void)checkSystemTwitterAccountsAgainstAccount:(HPAccount *)account {
    ACAccountType *twitterAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:
                                         ACAccountTypeIdentifierTwitter];
    
    NSArray *systemTwitterAccounts = [_accountStore accountsWithAccountType:twitterAccountType];
    NSLog(@">>> SYSTEM ACCOUNTS: %@", systemTwitterAccounts);
    if (systemTwitterAccounts == nil || [systemTwitterAccounts count] == 0) {
        if (_authHandler != nil) {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorNoAccountFound];
        }
        
        return;
    }
    
    if (account != nil) {
        NSLog(@">>> LOOKING FOR %@", account.identifier);
        for (ACAccount *systemTwitterAccount in systemTwitterAccounts) {
            NSLog(@">>> CHECKING ACCOUNT: %@", systemTwitterAccount);
            if (systemTwitterAccount.username != nil) {
                NSString *accountID = [[systemTwitterAccount valueForKeyPath:@"properties.user_id"] stringValue];
                NSLog(@"ACCOUNT ID: %@", accountID);
                if ([accountID isEqualToString:account.identifier]) {
                    _twitterAccount = [systemTwitterAccount retain];
                    
                    if (_authHandler != nil) {
                        [self completeAuthProcessWithAccount:account
                                                 profileInfo:nil
                                                       error:HPAccountManagerErrorNone];
                    }
                    
                    return;
                }
            }
        }
    }
    
    if ([systemTwitterAccounts count] == 1) {
        [self generateTokenForTwitterAccount:[systemTwitterAccounts objectAtIndex:0]];
    } else {
        dispatch_block_t completionBlock = ^{
            UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                          initWithTitle:NSLocalizedString(@"Select an account", nil)
                                          delegate:self
                                          cancelButtonTitle:nil
                                          destructiveButtonTitle:nil
                                          otherButtonTitles:nil];
            
            for (ACAccount *systemTwitterAccount in systemTwitterAccounts) {
                [actionSheet addButtonWithTitle:systemTwitterAccount.accountDescription];
            }
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
            [actionSheet setCancelButtonIndex:[systemTwitterAccounts count]];
            
            HPAppDelegate *appDelegate = (HPAppDelegate *)[[UIApplication sharedApplication] delegate];
            
            [actionSheet showInView:appDelegate.window];
            [actionSheet release];
        };
        
        if (dispatch_get_current_queue() == dispatch_get_main_queue()) {
            completionBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), completionBlock);
        }
    }
}

- (void)generateTokenForTwitterAccount:(ACAccount *)twitterAccount {
    [_twitterManager performReverseAuthForAccount:twitterAccount
                                      withHandler:^(NSData *responseData, NSError *error) {
                                          if (error != nil) {
                                              [self completeAuthProcessWithAccount:nil
                                                                       profileInfo:nil
                                                                             error:HPAccountManagerErrorAuthenticationFailed];
                                              
                                              return;
                                          }
                                          
                                          NSString *response = [[NSString alloc]
                                                                initWithData:responseData
                                                                encoding:NSUTF8StringEncoding];
                                          
                                          NSArray *components = [response componentsSeparatedByString:@"&"];
                                          NSString *token = nil;
                                          NSString *tokenSecret = nil;
                                          
                                          for (NSString *component in components) {
                                              NSArray *parts = [component componentsSeparatedByString:@"="];
                                              
                                              if ([[parts objectAtIndex:0] isEqualToString:@"oauth_token"]) {
                                                  token = [parts objectAtIndex:1];
                                              } else if ([[parts objectAtIndex:0] isEqualToString:@"oauth_token_secret"]) {
                                                  tokenSecret = [parts objectAtIndex:1];
                                              }
                                          }
                                          
                                          if (token == nil || tokenSecret == nil) {
                                              [self completeAuthProcessWithAccount:nil
                                                                       profileInfo:nil
                                                                             error:HPAccountManagerErrorAuthenticationFailed];
                                              
                                              return;
                                          }
                                          
                                          NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
                                          NSLog(@">>> STORING TOKEN: %@ / SECRET: %@", token, tokenSecret);
                                          [prefs setObject:token forKey:STAccountManagerTwitterTokenKey];
                                          [prefs setObject:tokenSecret forKey:STAccountManagerTwitterSecretKey];
                                          [prefs synchronize];

                                          [self fetchDetailsForTwitterAccount:twitterAccount];
                                      }];
}

- (void)fetchDetailsForTwitterAccount:(ACAccount *)twitterAccount {
    TWRequest *request = [[TWRequest alloc] initWithURL:[NSURL URLWithString:STAccountManagerTwitterVerifyURL]
                                             parameters:nil
                                          requestMethod:TWRequestMethodGET];

    [request setAccount:twitterAccount];
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if ([urlResponse statusCode] != 200) {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];

            return;
        }

        NSError *parseError = nil;
        NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:responseData
                                                                 options:0
                                                                   error:&parseError];

        if (parseError == nil) {
            HPAccount *account = [HPAccount accountWithType:HPAccountTypeTwitter
                                                 identifier:[userInfo valueForKey:@"id_str"]];

            [self completeAuthProcessWithAccount:account
                                     profileInfo:userInfo
                                           error:HPAccountManagerErrorNone];
        } else {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];
        }
    }];
    
    [request release];
}

#pragma mark - UIActionSheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    ACAccountType *twitterAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:
                                         ACAccountTypeIdentifierTwitter];
    
    NSArray *systemTwitterAccounts = [_accountStore accountsWithAccountType:twitterAccountType];

    if (buttonIndex >= [systemTwitterAccounts count]) {
        [self completeAuthProcessWithAccount:nil
                                 profileInfo:nil
                                       error:HPAccountManagerErrorCancelled];
        
        return;
    }
    
    [self generateTokenForTwitterAccount:[systemTwitterAccounts objectAtIndex:buttonIndex]];
}

#pragma mark - Completion

- (void)completeAuthProcessWithAccount:(HPAccount *)account
                           profileInfo:(NSDictionary *)profileInfo
                                 error:(HPAccountManagerError)error {
    dispatch_block_t completionBlock = ^{
        switch (error) {
            case HPAccountManagerErrorNone: {
                _authHandler(account, profileInfo, nil);
                break;
            }
            default: {
                _authHandler(account, profileInfo, [NSError errorWithDomain:STAccountManagerErrorDomain
                                                                       code:error
                                                                   userInfo:nil]);
                break;
            }
        }
        
        [_authHandler release], _authHandler = nil;
    };
    
    if (dispatch_get_current_queue() == dispatch_get_main_queue()) {
        completionBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), completionBlock);
    }
}

#pragma mark - URL handling

- (BOOL)handleOpenURL:(NSURL *)url {
    return [_facebookSession handleOpenURL:url];
}

#pragma mark - Notifications

- (void)didReceiveApplicationDidBecomeActiveNotification:(NSNotification *)notification {
    [_facebookSession handleDidBecomeActive];
}

- (void)didReceiveApplicationWillTerminateNotification:(NSNotification *)notification {
    [_facebookSession close];
}

#pragma mark - Twitter Tokens

- (NSString *)twitterToken {
    return [[NSUserDefaults standardUserDefaults] objectForKey:STAccountManagerTwitterTokenKey];
}

- (NSString *)twitterTokenSecret {
    return [[NSUserDefaults standardUserDefaults] objectForKey:STAccountManagerTwitterSecretKey];
}

#pragma mark - Facebook Token

- (NSString *)facebookToken {
    return _facebookSession.accessToken;
}

@end
