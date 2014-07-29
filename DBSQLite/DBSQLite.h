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

#define DEBUG_LEVEL 1

#import "DBSQLiteModelProtocol.h"
#import "DBSQLiteQueue.h"

static NSString * const kDBSQLiteModeDelete   = @"DELETE";
static NSString * const kDBSQLiteModeTruncate = @"TRUNCATE";
static NSString * const kDBSQLiteModePersist  = @"PERSIST";
static NSString * const kDBSQLiteModeMemory   = @"MEMORY";
static NSString * const kDBSQLiteModeWAL      = @"WAL";
static NSString * const kDBSQLiteModeOn       = @"ON";
static NSString * const kDBSQLiteModeOff      = @"OFF";
static NSString * const kDBSQLiteModeDefault  = @"DEFAULT";
static NSString * const kDBSQLiteModeFile     = @"FILE";
static NSString * const kDBSQLiteModeNormal   = @"NORMAL";
static NSString * const kDBSQLiteModeFull     = @"FULL";

static NSDictionary * const DBSQLiteKeyMapDefault = nil;

@class DBSQLiteSchema;

@interface DBSQLite : NSObject

@property (assign, nonatomic, readonly) BOOL inTransaction;
@property (assign, nonatomic, readonly) int savepointCount;
@property (strong, nonatomic, readonly) NSString *databasePath;

@property (assign, nonatomic, readonly) BOOL foreignKeysActive;                  // Default: ON
@property (assign, nonatomic, readonly) BOOL caseSensitiveLike;                  // Default: OFF
@property (assign, nonatomic, readonly) NSTimeInterval busyTimeout;              // Default: 10 seconds
@property (strong, nonatomic, readonly) NSString *synchronous;                   // Default: NORMAL
@property (strong, nonatomic, readonly) NSString *journalMode;                   // Default: DELETE
@property (strong, nonatomic, readonly) NSString *temporaryStore;                // Default: MEMORY
@property (assign, nonatomic, readonly) NSJSONWritingOptions jsonWritingOptions; // Default: 0
@property (assign, nonatomic, readonly) NSJSONReadingOptions jsonReadingOptions; // Default: 0

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

// TODO: Savepoints are not reliable. Cannot determine if "inTransaction" after rollback
//- (void)savepoint:(NSString *)savepoint;
//- (void)releaseSavepoint:(NSString *)savepoint;
//- (void)rollbackSavepoint:(NSString *)savepoint;

- (void)setBusyTimeout:(NSTimeInterval)busyTimeout;
- (void)setForeignKeysEnabled:(BOOL)enabled;
- (void)setCaseSensitiveLike:(BOOL)caseSensitiveLike;
- (void)setSynchronous:(NSString *)synchronous;
- (void)setJournalMode:(NSString *)journalMode;
- (void)setTemporaryStore:(NSString *)temporaryStore;

- (void)setJsonWritingOptions:(NSJSONWritingOptions)jsonWritingOptions;
- (void)setJsonReadingOptions:(NSJSONReadingOptions)jsonReadingOptions;

- (NSString *)sql:(NSString *)sql, ...;

- (NSNumber *)lastInsertID;
- (BOOL)executeQuery:(NSString *)query, ...;
- (BOOL)executePlainQuery:(NSString *)query;

- (void)createIndex:(NSString *)name table:(NSString *)table column:(NSString *)column unique:(BOOL)unique;
- (void)createIndex:(NSString *)name table:(NSString *)table column:(NSString *)column;
- (void)dropIndex:(NSString *)name;

- (NSMutableArray *)fetchDictionary:(NSString *)query, ...;
- (NSMutableArray *)fetchObject:(NSString *)name query:(NSString *)query, ...;


- (DBSQLiteSchema *)buildSchema;

@end
