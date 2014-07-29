//
//  DBSQLiteQueue.m
//
//  Created by Dima Bart on 2014-03-31.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import "DBSQLiteQueue.h"
#import "DBSQLite.h"

static char * const kDBSQLiteQueueContextKey = "kDBSQLiteQueueContextKey";

@interface DBSQLiteQueue ()

@property (strong, nonatomic) dispatch_queue_t privateQueue;

@end

@implementation DBSQLiteQueue

#pragma mark - Init -
+ (instancetype)queueWithPath:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

+ (instancetype)queueWithDocumentsFile:(NSString *)file {
    return [[self alloc] initWithDocumentsFile:file];
}

+ (instancetype)queueWithBundleFile:(NSString *)file extension:(NSString *)extension {
    return [[self alloc] initWithBundleFile:file extension:extension];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        [self initialization];
        [self syncExecution:^(DBSQLite *database) {
           _database = [[DBSQLite alloc] initWithPath:path];
        }];
    }
    return self;
}

- (instancetype)initWithDocumentsFile:(NSString *)file {
    self = [super init];
    if (self) {
        [self initialization];
        [self syncExecution:^(DBSQLite *database) {
            _database = [[DBSQLite alloc] initWithDocumentsFile:file];
        }];
    }
    return self;
}

- (instancetype)initWithBundleFile:(NSString *)file extension:(NSString *)extension {
    self = [super init];
    if (self) {
        [self initialization];
        [self syncExecution:^(DBSQLite *database) {
            _database = [[DBSQLite alloc] initWithBundleFile:file extension:extension];
        }];
    }
    return self;
}

- (void)dealloc {
    _privateQueue = nil;
    _database     = nil;
}

#pragma mark - Initialization -
- (void)initialization {
    [self setupPrivateQueue];
}

#pragma mark - Setup -
- (void)setupPrivateQueue {
    _privateQueue = dispatch_queue_create("com.dbsqlite.privateQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_privateQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_queue_set_specific(_privateQueue, kDBSQLiteQueueContextKey, (__bridge void *)self, NULL);
}

#pragma mark - Execution -
- (void)syncExecution:(DBSQLiteQueueExecutionBlock)executionBlock {
    DBSQLiteQueue *thisQueue = (__bridge DBSQLiteQueue *)dispatch_get_specific(kDBSQLiteQueueContextKey);
    if (self == thisQueue) {
        NSLog(@"DBSQLite: About to deadlock com.dbsqlite.privateQueue. Aborting sync block execution");
        abort();
    }
    
    if (executionBlock) {
        dispatch_sync(_privateQueue, ^{
            executionBlock(_database);
        });
    }
}

- (void)asyncExecution:(DBSQLiteQueueExecutionBlock)executionBlock {
    if (executionBlock) {
        dispatch_async(_privateQueue, ^{
            executionBlock(_database);
        });
    }
}

@end
