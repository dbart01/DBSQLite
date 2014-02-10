//
//  DBSQLiteSchema.h
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DBSQLiteTable.h"
#import "DBSQLiteColumn.h"

@interface DBSQLiteSchema : NSObject

@property (strong, nonatomic, readonly) NSArray *tables;

- (instancetype)initWithTables:(NSArray *)tables;

@end
