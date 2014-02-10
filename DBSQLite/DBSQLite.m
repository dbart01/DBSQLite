//
//  DBSQLite.m
//
//  Created by Dima Bart on 1/10/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <sqlite3.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "DBSQLite.h"
#import "DBSQLiteSchema.h"

static NSMutableDictionary *_registeredClasses;
static NSMutableDictionary *_registeredClassMaps;
static NSMutableDictionary *_registeredClassTransformers;

static Class _stringClass;
static Class _numberClass;
static Class _dateClass;
static Class _dataClass;

@interface DBSQLite () {
    sqlite3               *_database;
    NSMutableDictionary   *_preparedStatements;
}

@end

@implementation DBSQLite

#pragma mark - Class Init -
+ (void)initialize {
    [super initialize];
    
    _registeredClasses           = [NSMutableDictionary new];
    _registeredClassMaps         = [NSMutableDictionary new];
    _registeredClassTransformers = [NSMutableDictionary new];
}

#pragma mark - Singleton -
+ (instancetype)sharedController {
    static DBSQLite *_sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

#pragma mark - Init -
- (instancetype)init {
    self = [super init];
    if (self) {
        [self initialization];
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        [self openConnectionToPath:path];
        [self initialization];
    }
    return self;
}

- (instancetype)initWithDocumentsFile:(NSString *)file {
    self = [super init];
    if (self) {
        [self openConnectionInDocuments:file];
        [self initialization];
    }
    return self;
}

- (void)initialization {
    dbsqlite_loadClasses();
    
    _preparedStatements  = [NSMutableDictionary new];
    
    [self defaultConfiguration];
}

- (void)dealloc {
    [self closeConnection];
}

#pragma mark - Config -
- (void)defaultConfiguration {
    [self setSynchronous:kDBSQLiteModeNormal];
    [self setJournalMode:kDBSQLiteModeDelete];
    [self setTemporaryStore:kDBSQLiteModeMemory];
}

#pragma mark - Schema Building -
- (DBSQLiteSchema *)buildSchema {
    NSMutableArray *tables = [NSMutableArray new];
    
    NSArray *tablesList = [self fetchDictionary:@"SELECT * FROM sqlite_master WHERE type = 'table' AND tbl_name != 'sqlite_sequence'"];
    for (NSDictionary *tableDict in tablesList) {
        
        [tables addObject:[self buildTable:tableDict[@"tbl_name"]]];
    }
    
    return [[DBSQLiteSchema alloc] initWithTables:tables];
}

- (DBSQLiteTable *)buildTable:(NSString *)tableName {
    NSMutableArray *columns = [NSMutableArray new];
    
    NSArray *columnsList = [self fetchDictionary:@"PRAGMA table_info(%s)", [tableName UTF8String]];
    for (NSDictionary *columnDict in columnsList) {
        DBSQLiteColumn *column = [[DBSQLiteColumn alloc] initWithDictionary:columnDict];
        [columns addObject:column];
    }
    
    return [[DBSQLiteTable alloc] initWithName:tableName columns:columns];;
}

#pragma mark - Register Model Classes -
+ (void)registerModelClass:(Class)class forName:(NSString *)name {
    if ([name length] < 1) {
        NSLog(@"DBSQLite: Cannot register class for <null> name.");
        abort();
    }
    
    if ([class conformsToProtocol:@protocol(DBSQLiteModelProtocol)]) {
        _registeredClasses[name]           = class;
        _registeredClassMaps[name]         = [class keyMapForModelObject];
        _registeredClassTransformers[name] = dbsqlite_materializeSelectors([class transformersForModelObject]);
    }
}

- (Class)classForName:(NSString *)name {
    if (!name) {
        [self throwError:@"Attempt to retrieve class with nil name."];
    }
    
    return _registeredClasses[name];
}

- (NSDictionary *)classMapForName:(NSString *)name {
    if (!name) {
        [self throwError:@"Attempt to retrieve class map with nil name."];
    }
    
    return _registeredClassMaps[name];
}

- (NSDictionary *)classTransformersForName:(NSString *)name {
    if (!name) {
        [self throwError:@"Attempt to retrieve class transformers with nil name."];
    }
    
    return _registeredClassTransformers[name];
}

#pragma mark - Connection -
- (BOOL)openConnectionToPath:(NSString *)filePath {
    BOOL success = (sqlite3_open([filePath UTF8String], &_database) == SQLITE_OK);
    if (!success) {
        [self throwError:@"Could not open database"];
    } else {
        _databasePath = filePath;
    }
    return success;
}

- (BOOL)openConnectionInDocuments:(NSString *)file  {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [self openConnectionToPath:[path stringByAppendingPathComponent:file]];
}

- (void)closeConnection {
    if (_database) {
        sqlite3_close(_database);
    } else {
        NSLog(@"DBSQLite: No database connection to close.");
    }
}

#pragma mark - Caching -
- (sqlite3_stmt *)statementForSQL:(NSString *)sql {
    return (sqlite3_stmt *)[_preparedStatements[sql] pointerValue];
}

- (void)cacheStatement:(sqlite3_stmt *)statement forSQL:(NSString *)sql {
    _preparedStatements[sql] = [NSValue valueWithPointer:statement];
}

- (void)clearStatementCache {
    [_preparedStatements enumerateKeysAndObjectsUsingBlock:^(NSString *sql, NSValue *value, BOOL *stop) {
        sqlite3_finalize((sqlite3_stmt *)[value pointerValue]);
    }];
    [_preparedStatements removeAllObjects];
}

#pragma mark - Transactions & Mode Setters -
- (void)startTransaction {
    if (!_inTransaction) {
        [self executeQuery:@"BEGIN;"];
        _inTransaction = YES;
    }
}

- (void)commitTransaction {
    if (_inTransaction) {
        [self executeQuery:@"COMMIT;"];
        [self clearStatementCache];
        _inTransaction = NO;
    }
}

- (void)rollbackTransaction {
    if (_inTransaction) {
        [self executeQuery:@"ROLLBACK;"];
        [self clearStatementCache];
        _inTransaction = NO;
    }
}

- (void)setSynchronous:(NSString *)synchronous {
    _synchronous = synchronous;
    [self executeSingleQuery:[self sql:@"PRAGMA synchronous = %@",synchronous]];
}

- (void)setJournalMode:(NSString *)journalMode {
    _journalMode = journalMode;
    [self executeSingleQuery:[self sql:@"PRAGMA journal_mode = %@",journalMode]];
}

- (void)setTemporaryStore:(NSString *)temporaryStore {
    _temporaryStore = temporaryStore;
    [self executeSingleQuery:[self sql:@"PRAGMA temp_store = %@",temporaryStore]];
}

#pragma mark - Make SQL -
- (NSString *)sql:(NSString *)sql, ... {
    va_list args;
    va_start(args, sql);
    CFStringRef string   = CFStringCreateWithFormatAndArguments(kCFAllocatorDefault, NULL, (__bridge CFStringRef)sql, args);
    va_end(args);
    
    char *escaped_string = sqlite3_mprintf("%q",[(__bridge NSString *)string UTF8String]);
    NSString *escaped    = CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, escaped_string, kCFStringEncodingUTF8));
    
    CFRelease(string);
    sqlite3_free(escaped_string);
    
    return escaped;
}

#pragma mark - Prepare Statement -
- (sqlite3_stmt *)prepareStatement:(NSString *)query {
    if (!_database) {
        [self throwError:@"No database connection established. Prepare statement cannot continue"];
    }
    
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(_database, query.UTF8String, -1, &statement, NULL) != SQLITE_OK) {
        [self throwError:@"Could not prepare query: %@",query];
    }
    return statement;
}

#pragma mark - Execute Query -
- (BOOL)executeQuery:(NSString *)query, ... {
    va_list args;
    va_start(args, query);
    
    sqlite3_stmt *statement = [self statementForSQL:query];
    if (!statement) {
        statement = [self prepareStatement:query];
        if (_inTransaction) {
            [self cacheStatement:statement forSQL:query];
        }
    }
    
    int arg_count = sqlite3_bind_parameter_count(statement);
    for (int i=1; i<=arg_count; i++) {
        dbsqlite_bindObject(va_arg(args, id), statement, i);
    }
    
    int status = sqlite3_step(statement);
    
    sqlite3_clear_bindings(statement);
    sqlite3_reset(statement);
    va_end(args);
    
    return (status == SQLITE_DONE || status == SQLITE_OK);
}

- (BOOL)executeSingleQuery:(NSString *)query {
    if (!_database) {
        [self throwError:@"No database connection established. Aborting query Execution"];
    }
    
    char *error = NULL;
    sqlite3_exec(_database, [query UTF8String], NULL, NULL, &error);
    if (error) {
        NSLog(@"DBSQLite: Error executing query: %s",sqlite3_errmsg(_database));
        sqlite3_free(error);
        return NO;
    }
    return YES;
}

#pragma mark - Fetch Query -
- (NSArray *)fetchDictionary:(NSString *)query, ... {
    va_list args;
    va_start(args, query);
    NSString *queryString = [[NSString alloc] initWithFormat:query arguments:args];
    va_end(args);
    
    sqlite3_stmt *statement     = [self prepareStatement:queryString];
    CFMutableArrayRef container = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    int columnCount = sqlite3_column_count(statement);
    if (columnCount > 0) {
        
        NSArray *names = dbsqlite_column_names(statement, columnCount);
        for (int i=0; sqlite3_step(statement) == SQLITE_ROW; i++) {
            
            CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            for (int i=0;i<columnCount;i++) {
                CFDictionarySetValue(dict, (__bridge CFTypeRef)names[i], (__bridge CFTypeRef)dbsqlite_object_for_column(statement, i));
            }
            CFArrayAppendValue(container, dict);
        }
    }
    
    sqlite3_finalize(statement);
    
    return CFBridgingRelease(container);
    
//    va_list args;
//    va_start(args, query);
//    NSString *queryString = [[NSString alloc] initWithFormat:query arguments:args];
//    va_end(args);
//    
//    sqlite3_stmt *statement   = [self prepareStatement:queryString];
//    NSMutableArray *container = [NSMutableArray new];
//    
//    int columnCount = sqlite3_column_count(statement);
//    if (columnCount > 0) {
//        
//        NSArray *names = dbsqlite_column_names(statement, columnCount);
//        for (int i=0; sqlite3_step(statement) == SQLITE_ROW; i++) {
//            
//            NSMutableDictionary *dict = [NSMutableDictionary new];
//            for (int i=0;i<columnCount;i++) {
//                dict[names[i]] = dbsqlite_object_for_column(statement, i);
//            }
//            [container addObject:dict];
//        }
//    }
//    
//    sqlite3_finalize(statement);
//    
//    return container;
    
}

- (NSArray *)fetchObject:(NSString *)name query:(NSString *)query, ... {
    
    Class class                = [self classForName:name];
    NSDictionary *map          = [self classMapForName:name];
    NSDictionary *transformers = [self classTransformersForName:name];
    BOOL validMap              = ([map count] > 0);
    
    if (!class || !validMap) {
        NSLog(@"DBSQLite: Invalid class name or empty class map. Aborting fetch operation");
        return nil;
    }
    
    va_list args;
    va_start(args, query);
    NSString *queryString = [[NSString alloc] initWithFormat:query arguments:args];
    va_end(args);
    
    sqlite3_stmt *statement   = [self prepareStatement:queryString];
    NSMutableArray *container = [NSMutableArray new];
    
    int columnCount = sqlite3_column_count(statement);
    if (columnCount > 0) {
        
        NSArray *names = dbsqlite_column_names(statement, columnCount);
        for (int row=0; sqlite3_step(statement) == SQLITE_ROW; row++) {
            
            id objectContainer = [[class alloc] init];
            for (int i=0;i<columnCount;i++) {
                NSString *mappedKey = [map objectForKey:names[i]];
                if (mappedKey) {
                    
                    SEL selector = [[transformers objectForKey:names[i]] pointerValue];
                    if (selector) {
                        id value = dbsqlite_object_for_column(statement, i);
                        [objectContainer setValue:objc_msgSend(class, selector, value) forKey:mappedKey];
                    } else {
                        [objectContainer setValue:dbsqlite_object_for_column(statement, i) forKey:mappedKey];
                    }
                    
                }
            }
            [container addObject:objectContainer];
        }
    }
    
    sqlite3_finalize(statement);
    
    return container;
}

#pragma mark - SQLite Errors -
- (void)throwError:(NSString *)message, ... {
    va_list args;
    va_start(args, message);
    NSString *string = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    
    NSLog(@"DBSQLite: %@: %s", string, sqlite3_errmsg(_database));
    abort();
}

#pragma mark - Functions -
void dbsqlite_loadClasses() {
    if (!_stringClass) _stringClass = [NSString class];
    if (!_numberClass) _numberClass = [NSNumber class];
    if (!_dateClass)   _dateClass   = [NSDate class];
    if (!_dataClass)   _dataClass   = [NSData class];
}

NSArray * dbsqlite_column_names(sqlite3_stmt *statement, int columnCount) {
    CFMutableArrayRef container = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    for (int i=0;i<columnCount;i++) {
        CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, sqlite3_column_name(statement, i), kCFStringEncodingUTF8);
        CFArrayAppendValue(container, name);
    }
    return CFBridgingRelease(container);
    
//    NSMutableArray *container = [NSMutableArray new];
//    for (int i=0;i<columnCount;i++) {
//        [container addObject:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
//    }
//    return container;
}

void dbsqlite_bindObject(id object, sqlite3_stmt *statement, int column) {
    
    if ([object isKindOfClass:_stringClass]) {
        sqlite3_bind_text(statement, column, [(NSString *)object UTF8String], -1, SQLITE_TRANSIENT);
        
    } else if ([object isKindOfClass:_numberClass]) {
        dbsqlite_bindNumber(statement, column, (NSNumber *)object);
        
    } else if ([object isKindOfClass:_dateClass]) {
        sqlite3_bind_double(statement, column, [(NSDate *)object timeIntervalSince1970]);
        
    } else if ([object isKindOfClass:_dataClass]) {
        sqlite3_bind_blob(statement, column, [(NSData *)object bytes], (int)[(NSData *)object length], SQLITE_TRANSIENT);
        
    } else {
        sqlite3_bind_null(statement, column);
        
    }
}

void dbsqlite_bindNumber(sqlite3_stmt *statement, int column, NSNumber *number) {
    CFNumberType type = CFNumberGetType((__bridge CFNumberRef)number);
    switch (type) {
            
        case kCFNumberSInt8Type:
        case kCFNumberSInt16Type:
        case kCFNumberSInt32Type:
        case kCFNumberIntType:
        case kCFNumberShortType:
        case kCFNumberCharType:
        case kCFNumberCFIndexType:
            sqlite3_bind_int(statement, column, [number intValue]);
            break;
            
        case kCFNumberLongType:
        case kCFNumberLongLongType:
        case kCFNumberSInt64Type:
        case kCFNumberNSIntegerType:
            sqlite3_bind_int64(statement, column, [number longLongValue]);
            break;
            
        case kCFNumberFloat32Type:
        case kCFNumberFloat64Type:
        case kCFNumberFloatType:
        case kCFNumberCGFloatType:
        case kCFNumberDoubleType:
            sqlite3_bind_double(statement, column, [number doubleValue]);
            break;
    }
}

id dbsqlite_object_for_column(sqlite3_stmt *statement, int columnNumber) {
    int columnType = sqlite3_column_type(statement, columnNumber);
    switch (columnType) {
        case SQLITE_INTEGER:
            return @(sqlite3_column_int(statement, columnNumber));
            break;
            
        case SQLITE_FLOAT:
            return @(sqlite3_column_double(statement, columnNumber));
            break;
            
        case SQLITE_TEXT:
            return CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, (const char *)sqlite3_column_text(statement, columnNumber), kCFStringEncodingUTF8));
            break;
            
        case SQLITE_BLOB:
            return [[NSData alloc] initWithBytes:sqlite3_column_blob(statement, columnNumber) length:sqlite3_column_bytes(statement, columnNumber)];
            break;
            
        case SQLITE_NULL:
            return [NSNull null];
            break;
            
        default:
            NSLog(@"DBSQLite: Unable to retrieve data type for column: %s | index: %i",sqlite3_column_name(statement, columnNumber), columnNumber);
            return [NSNull null];
            break;
    }
}

NSDictionary * dbsqlite_materializeSelectors(NSDictionary *dictionary) {
    CFMutableDictionaryRef container = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *selectorString, BOOL *stop) {
        CFDictionarySetValue(container, (__bridge CFTypeRef)key, (__bridge CFTypeRef)[NSValue valueWithPointer:NSSelectorFromString(selectorString)]);
    }];
    return CFBridgingRelease(container);
    
    
//    NSMutableDictionary *container = [NSMutableDictionary new];
//    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *selectorString, BOOL *stop) {
//        container[key] = [NSValue valueWithPointer:NSSelectorFromString(selectorString)];
//    }];
//    return container;
}

@end
