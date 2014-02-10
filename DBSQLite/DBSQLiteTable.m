//
//  DBSQLiteTable.m
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import "DBSQLiteTable.h"

@interface DBSQLiteTable ()



@end

@implementation DBSQLiteTable

#pragma mark - Init -
- (instancetype)initWithName:(NSString *)name columns:(NSArray *)columns {
    self = [super init];
    if (self) {
        _name    = name;
        _columns = [columns copy];
    }
    return self;
}

//#pragma mark - Description -
//- (NSString *)description {
//    return [NSString stringWithFormat:@"%@:\n%@", _name, _columns];
//}

@end
