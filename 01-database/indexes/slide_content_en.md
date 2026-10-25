## Slide 1: Indexes
**Notes:**
Today I will talk about database indexes. It takes about 15 minutes: 5 parts, then a Q&A. This presentation covers the key points. If you have a question, please take note and ask it in the Q&A.

## Slide 2: What is an Index?
**Notes:**
First, without an index? what happens?
- The database must read the whole table to find the data.
- This is called a **full table scan**.

with An index,searching is faster:
- index helps the database find the right rows without reading the whole table. This is a **an extra structure**

But there is a trade-off:

- Reads are faster, but writes are slower because each change must update the index.
- Indexes use extra space, so they’re useful for large tables that don’t change often. If a table changes a lot, we should be careful when adding indexes.

## Slide 3: What is a B-tree?
**Notes:**
how does an index make search faster?

- Different index types use different data structures. For example, a B-tree index uses a tree structure, a Hash index uses hashing, and a GIN index uses an inverted index structure.
For example, a B-tree index is the most common type of index. It uses a tree structure, where the index keeps the data in order.

- This helps the database find data quickly without scanning the whole table.
- The search starts at the top and moves down the tree to find the data.
-And because the leaf nodes are linked together, range searches are faster

## Slide 4: How Many Types of Index?
**Notes:**
There are **8 main types**. Such as: B-tree, Unique, Full-text/Gin, Partial,Covering, Clustered, Non-clustered

### 1. B-tree
- This is the default index.
- It works for equality, range, ORDER BY, and prefix search like `LIKE 'abc%'`.
- It does not work for `LIKE '%abc'`, because the wildcard is at the start.
- `[MySQL]` `LIKE 'abc%'` uses the index directly.
- `[PostgreSQL]` needs the `text_pattern_ops` operator class (or "C" collation) for `LIKE 'abc%'`.
- If many rows have the same key, the database finds the key, then reads the next leaf nodes.

### 2. Unique index: It also uses a B-tree structure, but with one extra rule: duplicate values are not allowed.
- If the column already has duplicate values, we cannot create the index.
- Once it's created, it prevents new duplicates.
- And in some databases, NULL values can still repeat.

### 3. Composite
- An index on several columns. It follows the **leftmost prefix** rule.
- Example: index `(a, b, c)`
  - It works for `a`, `(a, b)` and `(a, b, c)`.
  - It usually does not work for `b` or `c` alone.
  - `[PostgreSQL]` 18 and later can sometimes do it (skip scan).

### 4. Full-text/Gin
- It is for searching text, when `LIKE` with a leading wildcard cannot use an index.

### 5. Partial
- It indexes only the rows that match a condition.

### 6. Covering
- The index holds every column the query needs, so the table is never read.
- `[PostgreSQL]` 11 and later uses `INCLUDE`.
- `[MySQL]` has no `INCLUDE`. Put the extra columns in a composite index.

### 7. Clustered
- It sets the physical order of the rows, so a table has only one.
- `[MySQL]` InnoDB uses the primary key as the clustered index.
- `[PostgreSQL]` has no real clustered index. The `CLUSTER` command only sorts the table once.

### 8. Non-clustered
- A extra structure that points to physical rows in the table. A table can have many.
- MySQL calls it a secondary index.
  
## Slide 5: 7 Common Indexing Mistakes
**Notes:**
There are 7 common mistakes.
1. **Many single-column indexes.** If columns are used together in one query, use one composite index.
2. **Wrong column order** in a composite index.
- Column order:
  - Equality columns first, then the first range column.
  - Among equality columns, put the most selective column first (a rule of thumb, not a law).
  - Columns after a range column cannot help the search.
4. **A function on an indexed column** (the most important one):
   - Example: `LOWER(email)`, YEAR(). The index usually stops working.
5. **Too many indexes.** Writes get slower.
6. **No index on a foreign key:** (avoid database nested loop full scans)
   - `[PostgreSQL]` does not create it for you.
   - `[MySQL]` InnoDB does.
7. **Ignoring NULLs.** For example, to skip NULL rows:
   - `[PostgreSQL]` use a partial index.
   - `[MySQL]` has no partial index.
8. **Never checking if an index is used.** Use system views to find and drop unused indexes

## Slide 6: How Do I Know an Index Is Used?
**Notes:**
Last question: how do we know an index is working? Don't guess. Ask the database.
- `[Both]` `EXPLAIN` shows the planned steps. It does **not** run the query. Use it to see if an index is used.
- `[Both]` `EXPLAIN ANALYZE` **runs the query** and shows real rows and real time.
 EXPLAIN is a big topic. Today we only cover the basics.
