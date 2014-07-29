//
//  DBSQLiteQueue.h
//
//  Created by Dima Bart on 2014-03-31.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DBSQLite;

typedef void (^DBSQLiteQueueExecutionBlock)(DBSQLite *database);

@interface DBSQLiteQueue : NSObject

@property (strong, nonatomic, readonly) DBSQLite *database;

+ (instancetype)queueWithPath:(NSString *)path;
+ (instancetype)queueWithDocumentsFile:(NSString *)file;
+ (instancetype)queueWithBundleFile:(NSString *)file extension:(NSString *)extension;

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithDocumentsFile:(NSString *)file;
- (instancetype)initWithBundleFile:(NSString *)file extension:(NSString *)extension;

- (void)syncExecution:(DBSQLiteQueueExecutionBlock)executionBlock;
- (void)asyncExecution:(DBSQLiteQueueExecutionBlock)executionBlock;

@end
