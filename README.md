DBSQLite
========

A simple, fast and object-oriented Objective-C framework for working with SQLite3 databases.

To create a fully-functional SQLite database file in the Documents directory of your application, simply create an instance of <code>DBSQLite</code>:
<pre>
DBSQLite *database = [[DBSQLite alloc] initWithDocumentsFile:@"database.sqlite"];
</pre>

