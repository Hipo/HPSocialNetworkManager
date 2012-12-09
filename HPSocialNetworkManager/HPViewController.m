//
//  HPViewController.m
//  HPSocialNetworkManager
//
//  Created by Sarp Erdag on 12/3/12.
//  Copyright (c) 2012 Hipo. All rights reserved.
//

#import "HPViewController.h"
#import "HPAccount.h"
#import "HPAccountManager.h"


@interface HPViewController ()

@end


@implementation HPViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)didTapTwitterLoginButton {
    [[HPAccountManager sharedManager] authenticateAccountOfType:HPAccountTypeTwitter
                                                    withHandler:^(HPAccount *authenticatedAccount, NSDictionary *profileInfo, NSError *error) {
                                                        if (error) {
                                                            NSLog(@"error: %@", error);
                                                        } else {
                                                            NSLog(@"%@", authenticatedAccount.identifier);
                                                        }
                                                    }];
}

- (IBAction)didTapFacebookLoginButton {
    [[HPAccountManager sharedManager] authenticateAccountOfType:HPAccountTypeFacebook
                                                    withHandler:^(HPAccount *authenticatedAccount, NSDictionary *profileInfo, NSError *error) {
                                                        if (error) {
                                                            NSLog(@"error: %@", error);
                                                        } else {
                                                            NSLog(@"%@", authenticatedAccount.identifier);
                                                        }
                                                    }];
}

@end
