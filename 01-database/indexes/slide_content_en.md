# Slide content (English): Database Indexes

English version of `slide_content.md`, in simple and short words.

**Color code (on the slides and as tags in this file):**

- Orange = MySQL `[MySQL]`
- Teal = PostgreSQL `[PostgreSQL]`
- Navy = both databases `[Both]`
- A slide that has database-specific text shows this color key in the top-right corner.

---

## Slide 1: Indexes

**Notes:**

Today I will talk about database indexes. It takes about 15 minutes: 5 parts, then a Q&A. This presentation covers the key points. If you have a question, please take note and ask it in the Q&A.

1. What is an index?
2. What is a B-tree?
3. How many types of index? (with notes on column order and covering)
4. Common mistakes
5. How do we know an index is used? (`EXPLAIN` and `EXPLAIN ANALYZE`)

---

## Slide 2: What is an Index?

**Notes:**

First, without an index? what happens?
- The database must read the whole table to find the data.
- This is called a **full table scan**.

with An index,searching is faster:
- index helps the database find the right rows without reading the whole table. This is a **an extra structure**

But there is a trade-off:

- Reads are **faster**, writes are **slower**. Every INSERT, UPDATE and DELETE must also update the extra structure.
- An index uses more memory and disk space.
- So create indexes only when the table is big, or will grow.

Next question: how does an index make search faster?

- Different index types use different data structures. For example, a B-tree index uses a tree structure, a Hash index uses hashing, and a GIN index uses an inverted index structure.
- For example, a B-tree index, which is the most common, uses a tree structure.

---

## Slide 3: What is a B-tree?

**Notes:**

- B-tree is a common type of index.
- It helps the database find data quickly.
- The search starts at the top and moves down the tree until it finds the data.
- The data is stored at the bottom, and the leaves are linked together. This also makes range searches faster. 
- 
About the NOTE box on the slide:

- An index can also use hash or inverted structures.
- Today we only look at the B-tree.

---

## Slide 4: How Many Types of Index?

**Notes:**

There are **8 main types**. Let's go one by one.

### 1. B-tree

- This is the default index.
- It works for equality, range, ORDER BY, and prefix search like `LIKE 'abc%'`.
- It does not work for `LIKE '%abc'`, because the wildcard is at the start.
- `[MySQL]` `LIKE 'abc%'` uses the index directly.
- `[PostgreSQL]` needs the `text_pattern_ops` operator class (or "C" collation) for `LIKE 'abc%'`.
- If many rows have the same key, the database finds the key, then reads the next leaf nodes.

### 2. Unique

- A B-tree with one more rule: no duplicate values.
- It cannot be created if the column already has duplicates.
- Once created, it blocks every new duplicate.
- NULL values can usually repeat.

### 3. Composite

- An index on several columns. It follows the **leftmost prefix** rule.
- Example: index `(a, b, c)`
  - It works for `a`, `(a, b)` and `(a, b, c)`.
  - It usually does not work for `b` or `c` alone.
  - `[PostgreSQL]` 18 and later can sometimes do it (skip scan).
- Column order:
  - Equality columns first, then the first range column.
  - Among equality columns, put the most selective column first (a rule of thumb, not a law).
  - Columns after a range column cannot help the search.

### 4. Full-text

- It is for searching text, when `LIKE` with a leading wildcard cannot use an index.
- `[MySQL]` uses a `FULLTEXT` index.
- `[PostgreSQL]` uses GIN (full-text, JSONB, arrays) and GiST (geometry, ranges).
- The two work differently, so we count them as one type.

### 5. Partial

- It indexes only the rows that match a condition.
- `[PostgreSQL]` supports it.
- `[MySQL]` does not.

### 6. Covering

- The index holds every column the query needs, so the table is never read.
- `[PostgreSQL]` 11 and later uses `INCLUDE`.
- `[MySQL]` has no `INCLUDE`. Put the extra columns in a composite index.

### 7. Clustered

- It sets the physical order of the rows, so a table has only one.
- `[MySQL]` InnoDB uses the primary key as the clustered index.
- `[PostgreSQL]` has no real clustered index. The `CLUSTER` command only sorts the table once.

### 8. Non-clustered

- A separate structure that points to the rows. A table can have many.
- MySQL calls it a secondary index.

---

## Slide 5: 7 Common Indexing Mistakes

**Notes:**

Here are 7 common mistakes.

1. **Many single-column indexes.** If columns are used together in one query, use one composite index.
2. **Wrong column order** in a composite index.
3. **A function on an indexed column** (the most important one):
   - Example: `LOWER(email)`. The index usually stops working.
   - Fix: rewrite the query, or create an expression index.
4. **Too many indexes.** Writes get slower.
5. **No index on a foreign key:**
   - `[PostgreSQL]` does not create it for you.
   - `[MySQL]` InnoDB does.
6. **Ignoring NULLs.** For example, to skip NULL rows:
   - `[PostgreSQL]` use a partial index.
   - `[MySQL]` has no partial index.
7. **Never checking if an index is used.** Use system views to find and drop unused indexes:
   - `[PostgreSQL]` `pg_stat_user_indexes`
   - `[MySQL]` `sys.schema_unused_indexes`

---

## Slide 6: How Do I Know an Index Is Used?

**Notes:**

Last question: how do we know an index is working? Don't guess. Ask the database.

- `[Both]` `EXPLAIN` shows the planned steps. It does **not** run the query. Use it to see if an index is used.
- `[Both]` `EXPLAIN ANALYZE` **runs the query** and shows real rows and real time.
- `[MySQL]` `EXPLAIN ANALYZE` is available from 8.0.18.

How to read the result:

- `[PostgreSQL]` **Index Scan** or **Index Only Scan** means an index is used. **Seq Scan** means a full table scan.
- `[MySQL]` look at `key` (the index used) and `type`. `type = ALL` means a full table scan. `ref` or `range` means an index is used.
- A full scan is not always a problem. On a small table, or when a query reads most rows, it can be the best plan.

Notes:

- `EXPLAIN ANALYZE` runs the query for real. Be careful with INSERT, UPDATE and DELETE (you can wrap them in a transaction and roll back).
- EXPLAIN is a big topic. Today we only cover the basics.
