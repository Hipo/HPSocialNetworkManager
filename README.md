HPSocialNetworkManager
======================

iOS framework for handling authentication with Facebook and Twitter with 
reverse-auth support.

Thanks to native support for Facebook and Twitter accounts in iOS, it's much 
easier to implement one-tap login and registration to your apps now. However 
there are a few pain points in this process:

* iOS5 doesn't have native Facebook authentication support
* Twitter support between iOS5 and iOS6 is slightly different and confusing
* iOS-supported Twitter login uses a "global" Twitter app rather than your own, 
    so tokens cannot be used anywhere else
* A custom "reverse-auth" process needs to be implemented to obtain Twitter
    tokens that can be stored on server side
* Facebook no longer supports "offline access" permission, so your app needs to 
    reauthenticate at every launch, renewing its access token

HPSocialNetworkManager aims to ease the integration process by adding native 
support for all of these scenarios, and giving you a single interface that you 
can use to authenticate a user with one or more social networks.

Usage
-----

Basic usage is like this:

    [[HPAccountManager sharedManager] setupWithFacebookAppID:@"Facebook App ID"
                                      facebookAppPermissions:@[@"email", @"user_location", @"user_about_me"]
                                          twitterConsumerKey:@"Twitter Consumer Key"
                                       twitterConsumerSecret:@"Twitter Consumer Secret"];

    [[HPAccountManager sharedManager] authenticateAccountOfType:HPAccountTypeTwitter
                                                   withHandler:^(HPAccount *authenticatedAccount, NSDictionary *profileInfo, NSError *error) {
                                                       if (error) {
                                                           NSLog(@"Failed to authenticate: %@", error);
                                                       } else {
                                                           NSLog(@"Authenticated: %@", authenticatedAccount.identifier);
                                                       }
                                                   }];

And that's it! Completion block is called with an `HPAccount` instance that 
contains the identifier and account type, and a `profileInfo` dictionary that 
contains the raw profile data received from Twitter or Facebook.

You can see an example of this by checking out the example project in this repo.

Requirements
------------

Project comes bundled with the following dependencies:

* ABOAuthCore
* TWAPIManager

And it depends on the Facebook SDK to work properly. You can download it and 
include it in your project from https://developers.facebook.com/ios/

Required system frameworks are:

* libsqlite3.dylib
* AdSupport.framework
* Accounts.framework
* Twitter.framework
* Social.framework

If you find any issues, please open an issue here on GitHub, and feel free to 
send in pull requests with improvements and fixes. You can also get in touch
by emailing us at hello@hipo.biz.

Credits
-------

HPSocialNetworkManager is brought to you by 
[Taylan Pince](http://taylanpince.com) and the [Hipo Team](http://hipo.biz).

Special thanks to [Sarp Erdag](https://twitter.com/sarperdag) 
from [Apperto](http://www.apperto.com/) for his testing and contributions.


License
-------

HPSocialNetworkManager is licensed under the terms of the Apache License, 
version 2.0. Please see the LICENSE file for full details.
