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
        _columnType   = dbsqlite_typeForColumnString(dictionary[@"type"]);
        _defaultValue = dictionary[@"dflt_value"];
        _columnID     = dictionary[@"cid"];
        _columnName   = dictionary[@"name"];
    }
    return self;
}

#pragma mark - Description -
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:\n\
            column_id: %@,\n\
            type:      %@,\n\
            not_null:  %i,\n\
            is_p_key:  %i,\n\
            default:   %@,\n",
            _columnName,
            _columnID,
            dbsqlite_stringForColumnType(_columnType),
            _notNull,
            _primaryKey,
            _defaultValue
            ];
}

#pragma mark - Functions -
static DBSQLiteColumnType dbsqlite_typeForColumnString(NSString *string) {
    if ([string isEqualToString:@"INTEGER"]) {
        return DBSQLiteColumnTypeInteger;
        
    } else if ([string isEqualToString:@"BLOB"]) {
        return DBSQLiteColumnTypeBlob;
        
    } else if ([string isEqualToString:@"REAL"]) {
        return DBSQLiteColumnTypeReal;
        
    } else if ([string isEqualToString:@"TEXT"]) {
        return DBSQLiteColumnTypeText;
        
    } else if ([string isEqualToString:@"NULL"]) {
        return DBSQLiteColumnTypeNull;
    } else {
        return DBSQLiteColumnTypeNull;
    }
}

static NSString * dbsqlite_stringForColumnType(DBSQLiteColumnType type) {
    switch (type) {
        case DBSQLiteColumnTypeNull:    return @"<null>";
        case DBSQLiteColumnTypeInteger: return @"INTEGER";
        case DBSQLiteColumnTypeText:    return @"TEXT";
        case DBSQLiteColumnTypeReal:    return @"REAL";
        case DBSQLiteColumnTypeBlob:    return @"BLOB";
    }
}

@end
