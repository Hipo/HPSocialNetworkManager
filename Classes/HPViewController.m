//
//  HPViewController.m
//  HPSocialNetworkManager
//
//  Created by Sarp Erdag on 12/3/12.
//  Copyright (c) 2012 Hipo. All rights reserved.
//

#import "HPViewController.h"
#import "HPAccount.h"


@interface HPViewController ()

@end


@implementation HPViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [HPAccountManager sharedManager].delegate = self;
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

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSLog(@"Action sheet dismissed");
}

@end
