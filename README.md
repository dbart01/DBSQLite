DBSQLite
========

A simple, fast and object-oriented Objective-C framework for working with SQLite3 databases.

Create an instance of <pre>DBSQLite</pre>:
<code>
DBSQLite *database = [[DBSQLite alloc] initWithDocumentsFile:@"database.sqlite"];
</code>
This will create a fully-functional SQLite database file in the Documents directory of the application.
