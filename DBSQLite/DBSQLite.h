//
//  DBSQLite.h
//
//  Created by Dima Bart on 1/10/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>
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

@property (strong, nonatomic, readonly) NSString *synchronous;    // Default: NORMAL
@property (strong, nonatomic, readonly) NSString *journalMode;    // Default: DELETE
@property (strong, nonatomic, readonly) NSString *temporaryStore; // Default: MEMORY

+ (void)registerModelClass:(Class)class forName:(NSString *)name;
+ (instancetype)sharedController;

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithDocumentsFile:(NSString *)file;

- (BOOL)openConnectionToPath:(NSString *)filePath;
- (BOOL)openConnectionInDocuments:(NSString *)file;
- (void)closeConnection;

- (void)startTransaction;
- (void)commitTransaction;
- (void)rollbackTransaction;

- (void)setSynchronous:(NSString *)synchronous;
- (void)setJournalMode:(NSString *)journalMode;
- (void)setTemporaryStore:(NSString *)temporaryStore;

- (NSString *)sql:(NSString *)sql, ...;
- (BOOL)executeQuery:(NSString *)query, ...;
- (NSArray *)fetchDictionary:(NSString *)query, ...;
- (NSArray *)fetchObject:(NSString *)name query:(NSString *)query, ...;


- (DBSQLiteSchema *)buildSchema;

@end
