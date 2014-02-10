//
//  DBSQLiteColumn.h
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DBSQLiteColumn : NSObject

typedef enum {
    DBSQLiteColumnTypeNull    = 0,
    DBSQLiteColumnTypeInteger = 1,
    DBSQLiteColumnTypeText    = 2,
    DBSQLiteColumnTypeReal    = 3,
    DBSQLiteColumnTypeBlob    = 4,
} DBSQLiteColumnType;

@property (assign, nonatomic, readonly, getter = isNotNull)    BOOL notNull;
@property (assign, nonatomic, readonly, getter = isPrimaryKey) BOOL primaryKey;

@property (strong, nonatomic, readonly) id defaultValue;

@property (assign, nonatomic, readonly) DBSQLiteColumnType columnType;
@property (strong, nonatomic, readonly) NSNumber *columnID;
@property (strong, nonatomic, readonly) NSString *columnName;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
