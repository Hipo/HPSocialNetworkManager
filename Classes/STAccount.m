//
//  STAccount.m
//  Strum
//
//  Created by Taylan Pince on 2012-11-28.
//  Copyright (c) 2012 Strum. All rights reserved.
//

#import "STAccount.h"


@implementation STAccount

+ (STAccount *)accountWithInfo:(NSDictionary *)accountInfo {
    return [[[STAccount alloc] initWithAccountInfo:accountInfo] autorelease];
}

+ (STAccount *)accountWithType:(STAccountType)accountType
                    identifier:(NSString *)identifier {
    return [[[STAccount alloc] initWithaccountType:accountType
                                        identifier:identifier] autorelease];
}

- (id)initWithAccountInfo:(NSDictionary *)accountInfo {
    self = [super init];
    
    if (self) {
        _identifier = [[accountInfo nonNullValueForKey:@"identifier"] copy];
        _networkType = STAccountTypeUnknown;
        
        NSString *serviceName = [accountInfo nonNullValueForKey:@"service"];
        
        if ([serviceName isEqualToString:@"facebook"]) {
            _networkType = STAccountTypeFacebook;
        } else if ([serviceName isEqualToString:@"twitter"]) {
            _networkType = STAccountTypeTwitter;
        }
    }
    
    return self;
}

- (id)initWithaccountType:(STAccountType)accountType
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
        case STAccountTypeFacebook:
            return @"facebook";
            break;
        case STAccountTypeTwitter:
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
