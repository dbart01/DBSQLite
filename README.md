DBSQLite
========

A simple, fast and object-oriented Objective-C framework for working with SQLite3 databases.

Getting Started
----------------
To create a fully-functional SQLite database file in the Documents directory of your application, simply create an instance of the <code>DBSQLite</code> class with a single line of code:
<pre>
DBSQLite *database = [[DBSQLite alloc] initWithDocumentsFile:@"database.sqlite"];
</pre>

Let's create a new <code>user</code> table to store future users within an exclusive transaction:
<pre>
[database startExclusiveTransaction];
[database executePlainQuery:@"CREATE TABLE IF NOT EXISTS user (\
     userID         INTEGER UNIQUE PRIMARY KEY AUTOINCREMENT, \
     firstName      TEXT, \
     lastName       TEXT, \
     dateCreated    REAL \
     )"];
[database commitTransaction];
</pre>

We can then insert a new user and create an index. We can use Objective-C classes like NSString, NSNumber, NSDate, NSData and even NSArray and NSDictionary (as long as they only contain JSON obejcts) as arguments for insertion. DBSQLite will automatically convert them appropriately:

<pre>
NSDate *now = [NSDate date]; // Will be stored as a timeIntervalSince1970 (REAL number)
 
[database executeQuery:@"INSERT INTO user (firstName, lastName, dateCreated) VALUES (?, ?, ?)",
     @"John",
     @"Appleseed",
     now, 
     ];
[database createIndex:@"userNameIndex" table:@"user" column:@"firstName"];
</pre>

Complete list of supported object and scalar types inludes:

<pre>
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
</pre>

Making Queries
--------------
We can fetch all users, without creating subclasses, with a simple query. We then iterate over the collection using fast enumeration:
<pre>
NSArray *results = [database fetchDictionary:@"SELECT * FROM users"];
for (NSDictionary *userDictionary in results) {
     NSLog(@"First Name: %@", userDictionary[@"firstName"]);
}
</pre>
