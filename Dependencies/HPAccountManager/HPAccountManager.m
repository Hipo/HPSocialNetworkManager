//
//  HPAccountManager.m
//  HPSocialNetworkManager
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Hipo. All rights reserved.
//

#import "TWAPIManager.h"
#import "NSData+Base64.h"

#import "HPAccountManager.h"


static NSString * const HPAccountManagerErrorDomain = @"com.hipo.HPSocialNetworkManager.authError";
static NSString * const HPAccountManagerTwitterVerifyURL = @"http://api.twitter.com/1/account/verify_credentials.json";
static NSString * const HPAccountManagerTwitterTokenKey = @"twitterToken";
static NSString * const HPAccountManagerTwitterSecretKey = @"twitterSecret";
static NSString * const HPAccountManagerTwitterUsernameKey = @"twitterUsername";


@interface HPAccountManager (Private)

- (void)authenticateFacebookAccount;
- (void)authenticateTwitterAccount;

- (void)checkSystemTwitterAccountsAgainstUsername:(NSString *)username;
- (void)generateTokenForTwitterAccount:(ACAccount *)twitterAccount;
- (void)fetchDetailsForTwitterAccount:(ACAccount *)twitterAccount;

- (void)openFacebookSession;
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_authHandler release], _authHandler = nil;
    [_twitterAccount release], _twitterAccount = nil;
    [_accountStore release], _accountStore = nil;
    [_twitterManager release], _twitterManager = nil;
    [_facebookAppID release], _facebookAppID = nil;
    [_facebookPermissions release], _facebookPermissions = nil;
    
    [super dealloc];
}

#pragma mark - Setup

- (void)setupWithFacebookAppID:(NSString *)facebookAppID
        facebookAppPermissions:(NSArray *)facebookAppPermissions
            twitterConsumerKey:(NSString *)twitterConsumerKey
         twitterConsumerSecret:(NSString *)twitterConsumerSecret {
    
    if (_facebookAppID != nil || _twitterManager != nil) {
        return;
    }
    
    _facebookAppID = [facebookAppID copy];
    _facebookPermissions = [facebookAppPermissions copy];
    
    [FBSession setDefaultAppID:_facebookAppID];
    
    _authHandler = nil;
    _accountStore = [[ACAccountStore alloc] init];
    _twitterManager = [[TWAPIManager alloc] init];
    
    [_twitterManager setConsumerKey:twitterConsumerKey];
    [_twitterManager setConsumerSecret:twitterConsumerSecret];
    
    if ([self hasAuthenticatedAccountOfType:HPAccountTypeFacebook]) {
        [self authenticateFacebookAccount];
    }
    
    if (self.twitterToken != nil && self.twitterTokenSecret != nil && self.twitterUsername != nil) {
        [self checkSystemTwitterAccountsAgainstUsername:self.twitterUsername];
    }
}

#pragma mark - Authentication check

- (BOOL)hasAuthenticatedAccountOfType:(HPAccountType)accountType {
    switch (accountType) {
        case HPAccountTypeFacebook: {
            FBSessionState sessionState = [[FBSession activeSession] state];

            return (sessionState == FBSessionStateCreatedTokenLoaded ||
                    sessionState == FBSessionStateOpen ||
                    sessionState == FBSessionStateOpenTokenExtended);
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
        handler(nil, nil, [NSError errorWithDomain:HPAccountManagerErrorDomain
                                              code:HPAccountManagerErrorUnknownServiceType
                                          userInfo:nil]);
        
        return;
    }
    
    if (_authHandler != nil) {
        handler(nil, nil, [NSError errorWithDomain:HPAccountManagerErrorDomain
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
    if ([[FBSession activeSession] isOpen] && [self hasAuthenticatedAccountOfType:HPAccountTypeFacebook]) {
        [self fetchDetailsForFacebookAccount];
        
        return;
    }
    
    ACAccountStoreRequestAccessCompletionHandler completionHandler = ^(BOOL granted, NSError *error) {
        if (!granted || error != nil) {
            if ([error code] != ACErrorAccountNotFound) {
                [self completeAuthProcessWithAccount:nil
                                         profileInfo:nil
                                               error:HPAccountManagerErrorAuthenticationFailed];
            
                return;
            }
        }

        dispatch_block_t completionBlock = ^{
            [self openFacebookSession];
        };
        
        if (dispatch_get_current_queue() == dispatch_get_main_queue()) {
            completionBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), completionBlock);
        }
    };
    
    if ([_accountStore respondsToSelector:@selector(requestAccessToAccountsWithType:options:completion:)]) {
        ACAccountType *facebookAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:
                                              ACAccountTypeIdentifierFacebook];

        [_accountStore requestAccessToAccountsWithType:facebookAccountType
                                               options:@{
                                                        ACFacebookAppIdKey : _facebookAppID,
                                                        ACFacebookPermissionsKey : _facebookPermissions,
                                                        ACFacebookAudienceKey : ACFacebookAudienceEveryone
                                                        }
                                            completion:completionHandler];
    } else {
        [self openFacebookSession];
    }
}

- (void)openFacebookSession {
    BOOL authenticated = NO;
    
    authenticated = [FBSession openActiveSessionWithReadPermissions:_facebookPermissions
                                                       allowLoginUI:YES
                                                  completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                                      switch (status) {
                                                          case FBSessionStateClosed:
                                                              break;
                                                          case FBSessionStateClosedLoginFailed: {
                                                              [FBSession.activeSession closeAndClearTokenInformation];
                                                              break;
                                                          }
                                                          case FBSessionStateCreated:
                                                              break;
                                                          case FBSessionStateCreatedOpening:
                                                              break;
                                                          case FBSessionStateCreatedTokenLoaded:
                                                              break;
                                                          case FBSessionStateOpen:
                                                              break;
                                                          case FBSessionStateOpenTokenExtended:
                                                              break;
                                                          default:
                                                              break;
                                                      }

                                                      if (_authHandler == nil) {
                                                          return;
                                                      }
                                                      
                                                      if (status != FBSessionStateOpen && status != FBSessionStateOpenTokenExtended) {

                                                          [self completeAuthProcessWithAccount:nil
                                                                                   profileInfo:nil
                                                                                         error:HPAccountManagerErrorAuthenticationFailed];
                                                          
                                                          return;
                                                      }
                                                      
                                                      [self fetchDetailsForFacebookAccount];
                                                  }];
    
    if (authenticated) {
        [self fetchDetailsForFacebookAccount];
    }
}

- (void)fetchDetailsForFacebookAccount {
    [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
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
    
    ACAccountStoreRequestAccessCompletionHandler completionHandler = ^(BOOL granted, NSError *error) {
        if (!granted || error != nil) {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorAuthenticationFailed];
            
            return;
        }

        dispatch_block_t completionBlock = ^{
            [self checkSystemTwitterAccountsAgainstUsername:self.twitterUsername];
        };
        
        if (dispatch_get_current_queue() == dispatch_get_main_queue()) {
            completionBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), completionBlock);
        }
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

- (void)checkSystemTwitterAccountsAgainstUsername:(NSString *)username {
    ACAccountType *twitterAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:
                                         ACAccountTypeIdentifierTwitter];
    
    NSArray *systemTwitterAccounts = [_accountStore accountsWithAccountType:twitterAccountType];

    if (systemTwitterAccounts == nil || [systemTwitterAccounts count] == 0) {
        if (_authHandler != nil) {
            [self completeAuthProcessWithAccount:nil
                                     profileInfo:nil
                                           error:HPAccountManagerErrorNoAccountFound];
        }
        
        return;
    }
    
    if (username != nil) {
        for (ACAccount *systemTwitterAccount in systemTwitterAccounts) {
            if (systemTwitterAccount.username != nil) {
                if ([username isEqualToString:systemTwitterAccount.username]) {
                    _twitterAccount = [systemTwitterAccount retain];
                    
                    if (_authHandler != nil) {
                        NSString *accountID = [systemTwitterAccount valueForKeyPath:@"properties.user_id"];
                        HPAccount *account = [HPAccount accountWithType:HPAccountTypeTwitter
                                                             identifier:accountID];
                        
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
            
            UIWindow *mainWindow = [[UIApplication sharedApplication] keyWindow];
            
            if (mainWindow.rootViewController != nil) {
                [actionSheet showInView:mainWindow.rootViewController.view];
            } else {
                [actionSheet showInView:mainWindow];
            }
            
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
                                          
                                          [response release];
                                          
                                          if (token == nil || tokenSecret == nil) {
                                              [self completeAuthProcessWithAccount:nil
                                                                       profileInfo:nil
                                                                             error:HPAccountManagerErrorAuthenticationFailed];
                                              
                                              return;
                                          }
                                          
                                          NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

                                          [prefs setObject:token forKey:HPAccountManagerTwitterTokenKey];
                                          [prefs setObject:tokenSecret forKey:HPAccountManagerTwitterSecretKey];
                                          [prefs setObject:twitterAccount.username forKey:HPAccountManagerTwitterUsernameKey];
                                          [prefs synchronize];

                                          [self fetchDetailsForTwitterAccount:twitterAccount];
                                      }];
}

- (void)fetchDetailsForTwitterAccount:(ACAccount *)twitterAccount {
    TWRequest *request = [[TWRequest alloc] initWithURL:[NSURL URLWithString:HPAccountManagerTwitterVerifyURL]
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
            _twitterAccount = [twitterAccount retain];
            
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
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self.delegate actionSheet:actionSheet didDismissWithButtonIndex:buttonIndex];
}

#pragma mark - Completion

- (void)completeAuthProcessWithAccount:(HPAccount *)account
                           profileInfo:(NSDictionary *)profileInfo
                                 error:(HPAccountManagerError)error {
    if (_authHandler == nil) {
        return;
    }
    
    dispatch_block_t completionBlock = ^{
        switch (error) {
            case HPAccountManagerErrorNone: {
                _authHandler(account, profileInfo, nil);
                break;
            }
            default: {
                _authHandler(account, profileInfo, [NSError errorWithDomain:HPAccountManagerErrorDomain
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
    return [[FBSession activeSession] handleOpenURL:url];
}

#pragma mark - Notifications

- (void)didReceiveApplicationDidBecomeActiveNotification:(NSNotification *)notification {
    [[FBSession activeSession] handleDidBecomeActive];
}

- (void)didReceiveApplicationWillTerminateNotification:(NSNotification *)notification {
    [[FBSession activeSession] close];
}

#pragma mark - Twitter Tokens

- (NSString *)twitterToken {
    return [[NSUserDefaults standardUserDefaults] objectForKey:HPAccountManagerTwitterTokenKey];
}

- (NSString *)twitterTokenSecret {
    return [[NSUserDefaults standardUserDefaults] objectForKey:HPAccountManagerTwitterSecretKey];
}

- (NSString *)twitterUsername {
    return [[NSUserDefaults standardUserDefaults] objectForKey:HPAccountManagerTwitterUsernameKey];
}

#pragma mark - Facebook Token

- (NSString *)facebookToken {
    return [[FBSession activeSession] accessToken];
}

#pragma mark - Reset

- (void)resetCachedTokens {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    [prefs removeObjectForKey:HPAccountManagerTwitterTokenKey];
    [prefs removeObjectForKey:HPAccountManagerTwitterSecretKey];
    [prefs removeObjectForKey:HPAccountManagerTwitterUsernameKey];
    [prefs synchronize];
    
    [[FBSession activeSession] closeAndClearTokenInformation];
    
    [_twitterAccount release], _twitterAccount = nil;
}

@end
