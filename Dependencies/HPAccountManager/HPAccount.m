//
//  HPAccount.m
//  HPSocialNetworkManager
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

#import "HPAccount.h"


@implementation HPAccount

+ (HPAccount *)accountWithInfo:(NSDictionary *)accountInfo {
    return [[[HPAccount alloc] initWithAccountInfo:accountInfo] autorelease];
}

+ (HPAccount *)accountWithType:(HPAccountType)accountType
                    identifier:(NSString *)identifier {
    return [[[HPAccount alloc] initWithaccountType:accountType
                                        identifier:identifier] autorelease];
}

- (id)initWithAccountInfo:(NSDictionary *)accountInfo {
    self = [super init];
    
    if (self) {
        _identifier = [[accountInfo valueForKey:@"identifier"] copy];
        _networkType = HPAccountTypeUnknown;
        
        NSString *serviceName = [accountInfo valueForKey:@"service"];
        
        if ([serviceName isEqualToString:@"facebook"]) {
            _networkType = HPAccountTypeFacebook;
        } else if ([serviceName isEqualToString:@"twitter"]) {
            _networkType = HPAccountTypeTwitter;
        }
    }
    
    return self;
}

- (id)initWithaccountType:(HPAccountType)accountType
               identifier:(NSString *)identifier {
    self = [super init];
    
    if (self) {
        _networkType = accountType;
        _identifier = [identifier copy];
    }
    
    return self;
}

- (void)dealloc {
    [_identifier release], _identifier = nil;
    
    [super dealloc];
}

#pragma mark - Storage

- (NSString *)serviceName {
    switch (_networkType) {
        case HPAccountTypeFacebook:
            return @"facebook";
            break;
        case HPAccountTypeTwitter:
            return @"twitter";
            break;
        default:
            return @"none";
            break;
    }
}

- (NSDictionary *)pickledObjectForStorage {
    return @{
        @"identifier" : _identifier,
        @"service": self.serviceName,
    };
}

@end
