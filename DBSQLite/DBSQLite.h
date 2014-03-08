//
//  DBSQLite.h
//
//  Created by Dima Bart on 1/10/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//



    #if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
    #else
#import <AppKit/AppKit.h>
    #endif
#import "DBSQLiteModelProtocol.h"

static NSString * const kDBSQLiteModeDelete   = @"DELETE";
static NSString * const kDBSQLiteModeTruncate = @"TRUNCATE";
static NSString * const kDBSQLiteModePersist  = @"PERSIST";
static NSString * const kDBSQLiteModeMemory   = @"MEMORY";
static NSString * const kDBSQLiteModeWAL      = @"WAL";
static NSString * const kDBSQLiteModeOff      = @"OFF";
static NSString * const kDBSQLiteModeDefault  = @"DEFAULT";
static NSString * const kDBSQLiteModeFile     = @"FILE";
static NSString * const kDBSQLiteModeNormal   = @"NORMAL";
static NSString * const kDBSQLiteModeFull     = @"FULL";

@class DBSQLiteSchema;

@interface DBSQLite : NSObject

@property (assign, nonatomic, readonly) BOOL inTransaction;
@property (strong, nonatomic, readonly) NSString *databasePath;

@property (assign, nonatomic, readonly) NSJSONWritingOptions jsonWritingOptions; // Default: 0
@property (assign, nonatomic, readonly) NSJSONReadingOptions jsonReadingOptions; // Default: 0
@property (strong, nonatomic, readonly) NSString *synchronous;                   // Default: NORMAL
@property (strong, nonatomic, readonly) NSString *journalMode;                   // Default: DELETE
@property (strong, nonatomic, readonly) NSString *temporaryStore;                // Default: MEMORY

+ (instancetype)sharedDatabase;
+ (void)registerModelClass:(Class)class;

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithDocumentsFile:(NSString *)file;
- (instancetype)initWithBundleFile:(NSString *)file extension:(NSString *)extension;

- (BOOL)openConnectionToPath:(NSString *)filePath;
- (BOOL)openConnectionInDocuments:(NSString *)file;
- (BOOL)openConnectionInBundle:(NSString *)file extension:(NSString *)extension;
- (void)closeConnection;

- (void)startTransaction;
- (void)startExclusiveTransaction;
- (void)startImmediateTransaction;
- (void)commitTransaction;
- (void)rollbackTransaction;

- (void)setSynchronous:(NSString *)synchronous;
- (void)setJournalMode:(NSString *)journalMode;
- (void)setTemporaryStore:(NSString *)temporaryStore;

- (void)setJsonWritingOptions:(NSJSONWritingOptions)jsonWritingOptions;
- (void)setJsonReadingOptions:(NSJSONReadingOptions)jsonReadingOptions;

- (NSString *)sql:(NSString *)sql, ...;
- (BOOL)executeQuery:(NSString *)query, ...;
- (NSMutableArray *)fetchDictionary:(NSString *)query, ...;
- (NSMutableArray *)fetchObject:(NSString *)name query:(NSString *)query, ...;


- (DBSQLiteSchema *)buildSchema;

@end
