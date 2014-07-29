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

