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
[_database commitTransaction];
</pre>

We can then insert a new user. We can use Objective-C classes like NSString, NSNumber, NSDate, NSData and even NSArray and NSDictionary (as long as they only contain JSON obejcts) as arguments for insertion. DBSQLite will automatically convert them appropriately:
<pre>
NSDate *now = [NSDate date]; // Will be stored as a timeIntervalSince1970 (REAL number)
 
[_database executeQuery:@"INSERT INTO user (firstName, lastName, dateCreated) VALUES (?, ?, ?)",
     @"John",
     @"Appleseed",
     now, 
     ];
</pre>
