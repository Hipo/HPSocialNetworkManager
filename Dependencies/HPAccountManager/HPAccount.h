//
//  HPAccount.h
//  HPSocialNetworkManager
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Hipo. All rights reserved.
//

typedef enum {
    HPAccountTypeUnknown,
    HPAccountTypeFacebook,
    HPAccountTypeTwitter,
} HPAccountType;


@interface HPAccount : NSObject {
@private
    NSString *_identifier;
    HPAccountType _networkType;
}

@property (nonatomic, readonly, retain) NSString *identifier;
@property (nonatomic, readonly, assign) HPAccountType networkType;

+ (HPAccount *)accountWithInfo:(NSDictionary *)accountInfo;
+ (HPAccount *)accountWithType:(HPAccountType)accountType
                    identifier:(NSString *)identifier;

- (id)initWithAccountInfo:(NSDictionary *)accountInfo;
- (id)initWithaccountType:(HPAccountType)accountType
               identifier:(NSString *)identifier;

- (NSDictionary *)pickledObjectForStorage;
- (NSString *)serviceName;

@end
