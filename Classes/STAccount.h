//
//  STAccount.h
//  Strum
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

typedef enum {
    STAccountTypeUnknown,
    STAccountTypeFacebook,
    STAccountTypeTwitter,
} STAccountType;


@interface STAccount : NSObject {
@private
    NSString *_identifier;
    STAccountType _networkType;
}

@property (nonatomic, readonly, retain) NSString *identifier;
@property (nonatomic, readonly, assign) STAccountType networkType;

+ (STAccount *)accountWithInfo:(NSDictionary *)accountInfo;
+ (STAccount *)accountWithType:(STAccountType)accountType
                    identifier:(NSString *)identifier;

- (id)initWithAccountInfo:(NSDictionary *)accountInfo;
- (id)initWithaccountType:(STAccountType)accountType
               identifier:(NSString *)identifier;

- (NSDictionary *)pickledObjectForStorage;
- (NSString *)serviceName;

@end
