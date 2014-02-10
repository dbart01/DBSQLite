//
//  DBSQLiteColumn.m
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import "DBSQLiteColumn.h"

@interface DBSQLiteColumn ()



@end

@implementation DBSQLiteColumn

#pragma mark - Init -
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _notNull      = [dictionary[@"notnull"] boolValue];
        _primaryKey   = [dictionary[@"pk"] boolValue];
        _columnType   = [dictionary[@"type"] intValue];
        _defaultValue = dictionary[@"dflt_value"];
        _columnID     = dictionary[@"cid"];
        _columnName   = dictionary[@"name"];
    }
    return self;
}

//#pragma mark - Description -
//- (NSString *)description {
//    return [NSString stringWithFormat:@"\
//            name:     %@,\n\
//            id:       %@,\n\
//            type:     %@,\n\
//            not_null: %i,\n\
//            p_key:    %i,\n\
//            default:  %@,\n\
//            ",
//            _columnName,
//            _columnID,
//            [self stringForColumnType:_columnType],
//            _notNull,
//            _primaryKey,
//            _defaultValue
//            ];
//}
//
//- (NSString *)stringForColumnType:(DBSQLiteColumnType)type {
//    switch (type) {
//        case DBSQLiteColumnTypeNull:    return @"<null>";
//        case DBSQLiteColumnTypeInteger: return @"INTEGER";
//        case DBSQLiteColumnTypeText:    return @"TEXT";
//        case DBSQLiteColumnTypeReal:    return @"REAL";
//        case DBSQLiteColumnTypeBlob:    return @"BLOB";
//    }
//}

@end
