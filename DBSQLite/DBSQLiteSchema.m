//
//  DBSQLiteSchema.m
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import "DBSQLiteSchema.h"

@interface DBSQLiteSchema ()



@end

@implementation DBSQLiteSchema

#pragma mark - Init -
- (instancetype)initWithTables:(NSArray *)tables {
    self = [super init];
    if (self) {
        _tables = [tables copy];
    }
    return self;
}

#pragma mark - Description -
- (NSString *)description {
    return [[[_tables description] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\\" withString:@""];
}

@end
