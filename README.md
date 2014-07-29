DBSQLite
========

A simple, fast and object-oriented Objective-C framework for working with SQLite3 databases.

## Getting Started

To create a fully-functional SQLite database file in the Documents directory of your application, simply create an instance of the <code>DBSQLite</code> class with a single line of code:
```objc
DBSQLite *database = [[DBSQLite alloc] initWithDocumentsFile:@"database.sqlite"];
```

Let's create a new <code>user</code> table to store future users within an exclusive transaction:
```objc
[database startExclusiveTransaction];
[database executePlainQuery:@"CREATE TABLE IF NOT EXISTS user (\
     userID         INTEGER UNIQUE PRIMARY KEY AUTOINCREMENT, \
     firstName      TEXT, \
     lastName       TEXT, \
     dateCreated    REAL \
     )"];
[database commitTransaction];
```

We can then insert a new user and create an index. We can use Objective-C classes like NSString, NSNumber, NSDate, NSData and even NSArray and NSDictionary (as long as they only contain JSON obejcts) as arguments for insertion. DBSQLite will automatically convert them appropriately:

```objc
NSDate *now = [NSDate date]; // Will be stored as a timeIntervalSince1970 (REAL number)
 
[database executeQuery:@"INSERT INTO user (firstName, lastName, dateCreated) VALUES (?, ?, ?)",
     @"John",
     @"Appleseed",
     now, 
     ];
[database createIndex:@"userNameIndex" table:@"user" column:@"firstName"];
```

Complete list of supported object and scalar types inludes:

```objc
NSNull / nil      - stored as NULL
NSString          - stored as TEXT
NSNumber          - stored as INTEGER
NSURL             - stored as TEXT
NSData            - stored as BLOB
NSDate            - stored as REAL number
UIImage / NSImage - stored as PNG data / TIFF data
NSArray           - stored as TEXT
NSDictionary      - stored as TEXT

Scalar-types are supported using NSString functions:
     NSStringFromCGRect
     NSStringFromCGSize
     NSStringFromCGPoint
     NSStringFromCGAffineTransform
```

## Making Queries

We can fetch all users, without creating subclasses, with a simple query. We then iterate over the collection using fast enumeration:

```objc
NSArray *results = [database fetchDictionary:@"SELECT * FROM users"];
for (NSDictionary *user in results) {
     NSLog(@"First Name: %@", user[@"firstName"]);
}
```

A better way, is to create a model object instead and adopt the <code>DBSQLiteModelProtocol</code> with just one method.

```objc
@interface XYUser : NSObject <DBSQLiteModelProtocol>

@property (strong, nonatomic, readonly) NSNumber *userID;
@property (strong, nonatomic, readonly) NSString *firstName;
@property (strong, nonatomic, readonly) NSString *lastName;
@property (strong, nonatomic, readonly) NSDate *dateCreated;

+ (NSDictionary *)keyMapForModelObject;

@end

@implementation XYUser

+ (NSDictionary *)keyMapForModelObject {
     return DBSQLiteKeyMapDefault;
}

@end
```

A model object that conform to <code>DBSQLiteModelProtocol</code> provides a container for data when performing a fetch. Since it's very light-weight, it is actually faster than creating an <code>NSDictionary</code> for every returned row of data. It also has the benefit of converting the returned data to the correct types, which means <code>dateCreated</code> will contain a real <code>NSDate</code> object.

Before we can use <code>XYUser</code>, we **MUST** register it with <code>DBSQLite</code>. Doing so is very easy:
```objc
[DBSQLite registerModelClass:[XYUser class]];
```
