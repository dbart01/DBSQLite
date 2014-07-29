DBSQLite
========

A simple, fast and object-oriented Objective-C framework for working with SQLite3 databases.

Creating Datbase
----------------
To create a fully-functional SQLite database file in the Documents directory of your application, simply create an instance of the <code>DBSQLite</code> class with a single line of code:
<pre>
DBSQLite *database = [[DBSQLite alloc] initWithDocumentsFile:@"database.sqlite"];
</pre>

