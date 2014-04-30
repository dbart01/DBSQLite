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

static const char *_CGRectType            = "{CGRect={CGPoint=xx}{CGSize=xx}}";
static const char *_CGPointType           = "{CGPoint=xx}";
static const char *_CGSizeType            = "{CGSize=xx}";
static const char *_CGAffineTransformType = "{CGAffineTransform=xxxxxx}";

static Class _stringClass;
static Class _numberClass;
static Class _dateClass;
static Class _dataClass;
static Class _imageClass;
static Class _arrayClass;
static Class _dictionaryClass;
static Class _urlClass;

static CGFloat _screenScale;

@interface DBSQLite () {
    sqlite3               *_database;
    NSMutableDictionary   *_preparedStatements;
}

typedef id (*DBSQLiteConversionFunction)(id);

@end

@implementation DBSQLite

#pragma mark - Class Init -
+ (void)initialize {
    [super initialize];
    
    dbsqlite_loadStaticVariables();
    
    _registeredClasses           = [NSMutableDictionary new];
    _registeredClassMaps         = [NSMutableDictionary new];
    _registeredClassTransformers = [NSMutableDictionary new];
}

#pragma mark - Singleton -
+ (instancetype)sharedDatabase {
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

- (instancetype)initWithBundleFile:(NSString *)file extension:(NSString *)extension {
    self = [super init];
    if (self) {
        [self openConnectionInBundle:file extension:extension];
        [self initialization];
    }
    return self;
}

- (void)initialization {
    NSLog(@"SQLite Version: %s", SQLITE_VERSION);
    _preparedStatements  = [NSMutableDictionary new];
    
    [self defaultConfiguration];
}

- (void)dealloc {
    [self closeConnection];
}

#pragma mark - Config -
- (void)defaultConfiguration {
    _savepointCount = 0;
    
    [self setBusyTimeout:10];
    
    [self setForeignKeysEnabled:YES];
    [self setSynchronous:kDBSQLiteModeNormal];
    [self setJournalMode:kDBSQLiteModeDelete];
    [self setTemporaryStore:kDBSQLiteModeMemory];
    
    [self setJsonReadingOptions:0];
    [self setJsonWritingOptions:0];
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
    
    NSString *sql        = [self sql:@"PRAGMA table_info(%@)", tableName];
    NSArray *columnsList = [self fetchDictionary:sql];
    for (NSDictionary *columnDict in columnsList) {
        DBSQLiteColumn *column = [[DBSQLiteColumn alloc] initWithDictionary:columnDict];
        [columns addObject:column];
    }
    
    return [[DBSQLiteTable alloc] initWithName:tableName columns:columns];
}

#pragma mark - Register Model Classes -
+ (void)registerModelClass:(Class)class {
    if ([class conformsToProtocol:@protocol(DBSQLiteModelProtocol)]) {
        NSString *name                     = NSStringFromClass(class);
        
        _registeredClasses[name]           = class;
        _registeredClassMaps[name]         = [class keyMapForModelObject];
        
        NSDictionary *transformers         = dbsqlite_conversionDictionary(class);
        if (transformers) {
            _registeredClassTransformers[name] = transformers;
        }
        
    } else {
        NSAssert(0, @"DBSQLite: Cannot register class. Class must conform to DBSQLiteModelProtocol.");
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

- (BOOL)openConnectionInBundle:(NSString *)file extension:(NSString *)extension {
    return [self openConnectionToPath:[[NSBundle mainBundle] pathForResource:file ofType:extension]];
}

- (void)closeConnection {
    if (_database) {
        sqlite3_close(_database);
    } else {
        NSLog(@"DBSQLite: No database connection to close.");
    }
}

#pragma mark - Transactions -
- (void)startTransaction {
    if (!_inTransaction) {
        [self executePlainQuery:@"BEGIN;"];
        _inTransaction = YES;
    }
}

- (void)startExclusiveTransaction {
    if (!_inTransaction) {
        [self executePlainQuery:@"BEGIN EXCLUSIVE;"];
        _inTransaction = YES;
    }
}

- (void)startImmediateTransaction {
    if (!_inTransaction) {
        [self executePlainQuery:@"BEGIN IMMEDIATE;"];
        _inTransaction = YES;
    }
}

- (void)commitTransaction {
    if (_inTransaction) {
        [self executePlainQuery:@"COMMIT;"];
        [self clearStatementCache];
        _inTransaction = NO;
    }
}

- (void)rollbackTransaction {
    if (_inTransaction) {
        [self executePlainQuery:@"ROLLBACK;"];
        [self clearStatementCache];
        _inTransaction = NO;
    }
}

#pragma mark - Savepoints -
- (void)savepoint:(NSString *)savepoint {
    _inTransaction = YES;
    _savepointCount++;
    [self executePlainQuery:[self sql:@"SAVEPOINT %@;", savepoint]];
}

- (void)releaseSavepoint:(NSString *)savepoint {
    if (_savepointCount > 0) _savepointCount--;
    if (_savepointCount == 0) {
        _inTransaction = NO;
    }
    [self executePlainQuery:[self sql:@"RELEASE SAVEPOINT %@;", savepoint]];
}

- (void)rollbackSavepoint:(NSString *)savepoint {
    // TODO: Handle savepoint count (how to determine how many are left?)
    [self executePlainQuery:[self sql:@"ROLLBACK TRANSACTION TO SAVEPOINT %@;", savepoint]];
}

#pragma mark - Mode Setters -
- (void)setBusyTimeout:(NSTimeInterval)busyTimeout {
    _busyTimeout = busyTimeout;
    sqlite3_busy_timeout(_database, (int)(1000.0f * busyTimeout));
}

- (void)setForeignKeysEnabled:(BOOL)enabled {
    NSString *onString = (enabled) ? kDBSQLiteModeOn : kDBSQLiteModeOff;
    if ([self executePlainQuery:[self sql:@"PRAGMA foreign_keys = %@;", onString]]) {
        _foreignKeysActive = enabled;
    }
}

- (void)setSynchronous:(NSString *)synchronous {
    if ([self executePlainQuery:[self sql:@"PRAGMA synchronous = %@;",synchronous]]) {
        _synchronous = synchronous;
    }
}

- (void)setJournalMode:(NSString *)journalMode {
    if ([self executePlainQuery:[self sql:@"PRAGMA journal_mode = %@;",journalMode]]) {
        _journalMode = journalMode;
    }
}

- (void)setTemporaryStore:(NSString *)temporaryStore {
    if ([self executePlainQuery:[self sql:@"PRAGMA temp_store = %@;",temporaryStore]]) {
        _temporaryStore = temporaryStore;
    }
}

- (void)setJsonWritingOptions:(NSJSONWritingOptions)jsonWritingOptions {
    _jsonWritingOptions = jsonWritingOptions;
}

- (void)setJsonReadingOptions:(NSJSONReadingOptions)jsonReadingOptions {
    _jsonReadingOptions = jsonReadingOptions;
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

#pragma mark - Make SQL -
- (NSString *)sql:(NSString *)sql, ... {
    va_list args;
    va_start(args, sql);
    NSString *string = [[NSString alloc] initWithFormat:sql arguments:args];
    va_end(args);
    
    char *escaped_string = sqlite3_mprintf("%q",string.UTF8String);
    NSString *escaped    = [NSString stringWithUTF8String:escaped_string];
    
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
- (NSNumber *)lastInsertID {
    return @(sqlite3_last_insert_rowid(_database));
}

- (BOOL)executeQuery:(NSString *)query, ... {
    int status;
    @autoreleasepool {
        va_list args;
        va_start(args, query);
        
        sqlite3_stmt *statement = [self statementForSQL:query];
        if (!statement) {
            statement = [self prepareStatement:query];
            if (_inTransaction) {
                [self cacheStatement:statement forSQL:query];
            }
        }
        dbsqlite_bindStatementArgs(args, statement);
        
        status = sqlite3_step(statement);
        
        sqlite3_clear_bindings(statement);
        sqlite3_reset(statement);
        va_end(args);
    }
    
    //    if (status != SQLITE_DONE && status != SQLITE_OK) {
    //        NSLog(@"DBSQLite: Error executing query: %s", sqlite3_errmsg(_database));
    //    }
    
    return (status == SQLITE_DONE || status == SQLITE_OK);
}

- (BOOL)executePlainQuery:(NSString *)query {
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

#pragma mark - Index Management -
- (void)createIndex:(NSString *)name table:(NSString *)table column:(NSString *)column unique:(BOOL)unique {
    [self executePlainQuery:[self sql:@"CREATE %@ INDEX IF NOT EXISTS %@ ON %@ (%@)", (unique) ? @"UNIQUE" : @"", name, table, column]];
}

- (void)createIndex:(NSString *)name table:(NSString *)table column:(NSString *)column {
    [self createIndex:name table:table column:column unique:NO];
}

- (void)dropIndex:(NSString *)name {
    [self executePlainQuery:[self sql:@"DROP INDEX IF EXISTS %@", name]];
}

#pragma mark - Fetch Query -
- (NSMutableArray *)fetchDictionary:(NSString *)query, ... {
    va_list args;
    va_start(args, query);
    
    sqlite3_stmt *statement = [self prepareStatement:query];
    dbsqlite_bindStatementArgs(args, statement);
    
    va_end(args);
    
    NSMutableArray *container = [NSMutableArray new];
    
    int columnCount = sqlite3_column_count(statement);
    if (columnCount > 0) {
        
        NSArray *names = dbsqlite_column_names(statement, columnCount);
        for (int i=0; sqlite3_step(statement) == SQLITE_ROW; i++) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            for (int i=0;i<columnCount;i++) {
                [dict setObject:dbsqlite_object_for_column(statement, i, NO) forKey:names[i]];
            }
            [container addObject:dict];
        }
    }
    
    sqlite3_clear_bindings(statement);
    sqlite3_reset(statement);
    sqlite3_finalize(statement);
    
    return container;
}

- (NSMutableArray *)fetchObject:(NSString *)name query:(NSString *)query, ... {
    
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
    
    sqlite3_stmt *statement = [self prepareStatement:query];
    dbsqlite_bindStatementArgs(args, statement);
    
    va_end(args);
    
    NSMutableArray *container = [NSMutableArray new];
    
    int columnCount = sqlite3_column_count(statement);
    if (columnCount > 0) {
        
        NSArray *names = dbsqlite_column_names(statement, columnCount);
        for (int row=0; sqlite3_step(statement) == SQLITE_ROW; row++) {
            
            id objectContainer = [[class alloc] init];
            for (int i=0;i<columnCount;i++) {
                NSString *mappedKey = [map objectForKey:names[i]];
                if (mappedKey) {
                    
                    DBSQLiteConversionFunction converter = [transformers[mappedKey] pointerValue];
                    id value                             = dbsqlite_object_for_column(statement, i, YES);
                    if (converter) {
                        [objectContainer setValue:converter(value) forKey:mappedKey];
                    } else {
                        [objectContainer setValue:value forKey:mappedKey];
                    }
                    
                }
            }
            [container addObject:objectContainer];
        }
    }
    
    sqlite3_clear_bindings(statement);
    sqlite3_reset(statement);
    sqlite3_finalize(statement);
    
    return container;
}

#pragma mark - SQLite Errors -
- (void)throwError:(NSString *)message, ... {
    va_list args;
    va_start(args, message);
    NSString *string = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    
    NSAssert(0, @"DBSQLite: %@: %s", string, sqlite3_errmsg(_database));
}

#pragma mark - Load Functions -
static inline void dbsqlite_loadStaticVariables() {
    if (!_stringClass)     _stringClass     = [NSString class];
    if (!_numberClass)     _numberClass     = [NSNumber class];
    if (!_dateClass)       _dateClass       = [NSDate class];
    if (!_dataClass)       _dataClass       = [NSData class];
    if (!_arrayClass)      _arrayClass      = [NSArray class];
    if (!_dictionaryClass) _dictionaryClass = [NSDictionary class];
    if (!_urlClass)        _urlClass        = [NSURL class];
    
#if TARGET_OS_IPHONE
    if (!_imageClass)      _imageClass      = [UIImage class];
    if (!_screenScale)     _screenScale     = [[UIScreen mainScreen] scale];
#else
    if (!_imageClass)      _imageClass      = [NSImage class];
    if (!_screenScale)     _screenScale     = 1.0f;
#endif
}

#pragma mark - Object Operations & Binding -
static inline NSArray * dbsqlite_column_names(sqlite3_stmt *statement, int columnCount) {
    NSMutableArray *container = [NSMutableArray new];
    for (int i=0;i<columnCount;i++) {
        [container addObject:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
    }
    return container;
}

static inline void dbsqlite_bindObject(id object, sqlite3_stmt *statement, int column) {
    
    int status = -1;
    if ([object isKindOfClass:_stringClass]) {
        status = sqlite3_bind_text(statement, column, [(NSString *)object UTF8String], -1, SQLITE_TRANSIENT);
        
    } else if ([object isKindOfClass:_urlClass]) {
        status = sqlite3_bind_text(statement, column, [[(NSURL *)object absoluteString] UTF8String], -1, SQLITE_TRANSIENT);
        
    } else if ([object isKindOfClass:_numberClass]) {
        status = sqlite3_bind_int64(statement, column, [(NSNumber *)object longLongValue]);
        
    } else if ([object isKindOfClass:_dateClass]) {
        status = sqlite3_bind_double(statement, column, [(NSDate *)object timeIntervalSince1970]);
        
    } else if ([object isKindOfClass:_dataClass]) {
        status = sqlite3_bind_blob(statement, column, [(NSData *)object bytes], (int)[(NSData *)object length], SQLITE_TRANSIENT);
        
    } else if ([object isKindOfClass:_imageClass]) {
        
#if TARGET_OS_IPHONE
        NSData *data = UIImagePNGRepresentation(object);
#else
        NSData *data = [(NSImage *)object TIFFRepresentation];
#endif
        status = sqlite3_bind_blob(statement, column, [data bytes], (int)[data length], SQLITE_TRANSIENT);
        
    } else if ([object isKindOfClass:_arrayClass] || [object isKindOfClass:_dictionaryClass]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
        status = sqlite3_bind_blob(statement, column, [data bytes], (int)[data length], SQLITE_TRANSIENT);
        
    } else {
        status = sqlite3_bind_null(statement, column);
        
    }
    
    if (status != SQLITE_OK) {
        DBLog(@"DBSQLite: Error binding object, code: %d", status);
    }
}

static inline id dbsqlite_object_for_column(sqlite3_stmt *statement, int columnNumber, BOOL useNil) {
    int columnType = sqlite3_column_type(statement, columnNumber);
    switch (columnType) {
        case SQLITE_INTEGER:
            return @(sqlite3_column_int64(statement, columnNumber));
            break;
            
        case SQLITE_FLOAT:
            return @(sqlite3_column_double(statement, columnNumber));
            break;
            
        case SQLITE_TEXT:
            return [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, columnNumber)];
            break;
            
        case SQLITE_BLOB:
            return [[NSData alloc] initWithBytes:sqlite3_column_blob(statement, columnNumber) length:sqlite3_column_bytes(statement, columnNumber)];
            break;
            
        case SQLITE_NULL:
            return (useNil) ? nil : [NSNull null];
            break;
            
        default:
            NSLog(@"DBSQLite: Unable to retrieve data type for column: %s | index: %i",sqlite3_column_name(statement, columnNumber), columnNumber);
            return (useNil) ? nil : [NSNull null];
            break;
    }
}

static inline void dbsqlite_bindStatementArgs(va_list args, sqlite3_stmt *statement) {
    int arg_count = sqlite3_bind_parameter_count(statement);
    for (int i=1; i<=arg_count; i++) {
        dbsqlite_bindObject(va_arg(args, id), statement, i);
    }
}

#pragma mark - Registering Classes -
static NSDictionary * dbsqlite_conversionDictionary(Class class) {
    NSMutableDictionary *container = nil;
    
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
    for (int i=0;i<propertyCount;i++) {
        
        const char *className = NULL;
        const char *ivarName  = NULL;
        
        unsigned int attributeCount;
        objc_property_attribute_t *attributes = property_copyAttributeList(properties[i], &attributeCount);
        for (int i=0;i<attributeCount;i++) {
            objc_property_attribute_t attribute = attributes[i];
            switch (attribute.name[0]) {
                case 'T': className = attribute.value; break;
                case 'V': ivarName  = attribute.value; break;
            }
        }
        free(attributes);
        
        if (ivarName && className) {
            char *cName             = strndup(className+2, strlen(className)-3);
            Class propertyClass     = NSClassFromString([NSString stringWithUTF8String:cName]);
            free(cName);
            
            DBSQLiteConversionFunction conversionPointer = nil;
            
            // Handle object (id) types
            if (propertyClass) {
                conversionPointer = dbsqlite_conversionFunctionForPropertyClass(propertyClass);
                
                // Check if we're dealing with compatible CG structs
            } else {
                conversionPointer = dbsqlite_conversionFunctionForScalarType(className);
            }
            
            
            // We have something to work with, add it to the conversion dictionary
            if (conversionPointer) {
                char *pName            = strndup(ivarName+1, strlen(ivarName)-1);
                NSString *propertyName = [NSString stringWithUTF8String:pName];
                free(pName);
                
                if (!container) {
                    container = [NSMutableDictionary new];
                }
                container[propertyName] = [NSValue valueWithPointer:conversionPointer];
            }
        }
        
    }
    free(properties);
    
    return container;
}

static inline void * dbsqlite_conversionFunctionForPropertyClass(Class class) {
    if (class == _imageClass) {
        return &dbsqlite_convertDataToImage;
        
    } else if (class == _urlClass) {
        return &dbsqlite_convertStringToURL;
        
    } else if (class == _dateClass) {
        return &dbsqlite_convertIntervalToDate;
        
    } else if (class == _arrayClass || class == _dictionaryClass) {
        return &dbsqlite_convertDataToJSONObject;
        
    } else {
        return NULL;
    }
}

static inline void * dbsqlite_conversionFunctionForScalarType(const char *type) {
    
    char *new_type = dbsqlite_convertScalarType(type);
    void *function = NULL;
    
    if (strcmp(new_type, _CGRectType) == 0) {
        function = &dbsqlite_convertStringToCGRectValue;
        
    } else if (strcmp(new_type, _CGPointType) == 0) {
        function = &dbsqlite_convertStringToCGPointValue;
        
    } else if (strcmp(new_type, _CGSizeType) == 0) {
        function = &dbsqlite_convertStringToCGSizeValue;
        
    } else if (strcmp(new_type, _CGAffineTransformType) == 0) {
        function = &dbsqlite_convertStringToCGAffineTransformValue;
        
    }
    
    free(new_type);
    return function;
}

static inline char * dbsqlite_convertScalarType(const char *type) {
    int enabled          = 0;
    char *new_type       = strdup(type);
    unsigned long length = strlen(type);
    for (int i=0;i<length;i++) {
        
        if (new_type[i] == '=') {
            enabled = 1;
            continue;
        }
        
        if (new_type[i] == '}' || new_type[i] == '{') {
            enabled = 0;
            continue;
        }
        
        if (enabled == 1 && (new_type[i] == 'd' || new_type[i] == 'f')) {
            new_type[i] = 'x';
        }
    }
    return new_type;
}

#pragma mark - Class Conversion Functions -
static inline id dbsqlite_convertDataToJSONObject(NSData *data) {
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

static inline id dbsqlite_convertStringToURL(NSString *string) {
    return [[NSURL alloc] initWithString:string];
}

static inline NSDate * dbsqlite_convertIntervalToDate(NSNumber *timeInterval) {
    return [[NSDate alloc] initWithTimeIntervalSince1970:[timeInterval doubleValue]];
}

#if TARGET_OS_IPHONE
static inline UIImage * dbsqlite_convertDataToImage(NSData *data) {
    return [[UIImage alloc] initWithData:data scale:_screenScale];
}
#else
static inline NSImage * dbsqlite_convertDataToImage(NSData *data) {
    return [[NSImage alloc] initWithData:data];
}
#endif

#pragma mark - CG Conversion Functions -
static inline NSValue * dbsqlite_convertStringToCGRectValue(NSString *string) {
    return [NSValue valueWithCGRect:CGRectFromString(string)];
}

static inline NSValue * dbsqlite_convertStringToCGPointValue(NSString *string) {
    return [NSValue valueWithCGPoint:CGPointFromString(string)];
}

static inline NSValue * dbsqlite_convertStringToCGSizeValue(NSString *string) {
    return [NSValue valueWithCGSize:CGSizeFromString(string)];
}

static inline NSValue * dbsqlite_convertStringToCGAffineTransformValue(NSString *string) {
    return [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(string)];
}


#pragma mark - Logging -
static inline void DBLog(NSString *format, ...) {
#if DEBUG_LEVEL > 0
    va_list args;
    va_start(args, format);
    NSLogv(format, args);
    va_end(args);
#endif
}

@end
