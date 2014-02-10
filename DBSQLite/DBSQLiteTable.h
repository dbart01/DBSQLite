//
//  DBSQLiteTable.h
//
//  Created by Dima Bart on 2/7/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DBSQLiteTable : NSObject

@property (strong, nonatomic, readonly) NSString *name;
@property (strong, nonatomic, readonly) NSArray *columns;

- (instancetype)initWithName:(NSString *)name columns:(NSArray *)columns;

@end
