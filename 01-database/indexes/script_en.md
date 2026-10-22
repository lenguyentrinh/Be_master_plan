# Presentation script (English): Database Indexes

Target length: about 15 minutes, 6 slides. Text in `[brackets]` is a stage direction, not spoken.

Color code used on the slides: orange = MySQL, teal = PostgreSQL, navy = both.

---

## Slide 1: Indexes (about 1 minute)

Hi everyone. Today I will talk about indexes in databases. It will take about 15 minutes, in five parts, followed by a short Q&A.

This is only an overview. If you have questions along the way, please write them down and ask them in the Q&A at the end.

Here are the five parts:

1. What an index is.
2. What a B-tree is.
3. How many types of index there are, with a few notes on column order and covering indexes.
4. Common mistakes.
5. How to tell whether an index is actually being used.

---

## Slide 2: What is an Index? (about 2 minutes)

Let's start with what happens when a column has no index.

- The database has to read the whole table to find the rows you asked for.
- This is called a **full table scan**. `[point at the left diagram]`

An index solves that problem.

- It is an extra data structure, kept next to the table.
- It lets the database jump straight to the matching rows instead of scanning everything.

But an index is a trade-off. `[point at the right box]`

- Reads get **faster**, but writes get **slower**. Every INSERT, UPDATE or DELETE must also update the index.
- An index also uses extra memory and disk space.
- So only create indexes when the table is large, or when you expect it to grow.

Next question: how does an index make searching faster?

- There are many kinds of index structures, for example inverted, B-tree and hash.
- We will focus on the B-tree because it is the most common one.

---

## Slide 3: What is a B-tree? (about 2 minutes)

A B-tree is a tree-shaped data structure. It is the default and the most common index type. `[point at the tree diagram]`

When you search for a value:

1. The database starts at the **root** node.
2. It follows the **internal** nodes down the tree.
3. It ends at a **leaf** node that holds the value.

The leaf nodes are linked together in sorted order. That is why range searches and ORDER BY are fast too.

A small technical detail: databases call it a "B-tree", but in practice they use a B+tree. The data lives in the leaves, and the leaves are linked.

`[point at the NOTE box]` As the note says, an index can also use hash or inverted structures. Today we only look at the B-tree.

---

## Slide 4: How Many Types of Index? (about 4 minutes)

There are **8 main types** of index. Let's go through them one by one. `[point at the grid]`

**1. B-tree**

- It is the default index.
- It supports equality, ranges, ORDER BY, and prefix search such as `LIKE 'abc%'`.
- It does NOT support a leading wildcard such as `LIKE '%abc'`.
- On PostgreSQL, `LIKE 'abc%'` needs the `text_pattern_ops` operator class unless the database uses the "C" collation. `[teal]`
- When many rows share the same key, the database finds the key in the tree and then reads the neighbouring leaf nodes.

**2. Unique**

- It is a B-tree with one extra rule: no duplicate values.
- If the column already contains duplicates, you cannot create it.
- If it has no duplicates today, you can create it, and from then on it blocks any duplicate.
- NULL values are treated as different from each other, so they can usually repeat.

**3. Composite**

- It covers several columns and follows the **leftmost-prefix rule**.
- Take an index on `(a, b, c)`. It helps for `a`, for `(a, b)`, and for `(a, b, c)`.
- It usually does not help for `b` alone or `c` alone. PostgreSQL 18 can sometimes do it with a "skip scan". `[teal]`
- Column order: put equality columns first, then the first range column. Columns after a range column cannot narrow the search.
- Among equality columns, a common rule of thumb is to put the most selective column first. It is a guideline, not a law.

**4. Full-text**

- It is for searching inside text, in cases where `LIKE` with a leading wildcard cannot use an index.
- MySQL uses a `FULLTEXT` index. `[orange]`
- PostgreSQL uses GIN for full-text, JSONB and arrays, and GiST for geometric data and ranges. `[teal]`
- The two databases work differently, but they solve the same kind of problem, so we count them as one type.

**5. Partial**

- It indexes only the rows that match a condition.
- PostgreSQL supports it. `[teal]`
- MySQL does not. `[orange]`

**6. Covering**

- The index contains every column the query needs, so the database never has to read the table.
- PostgreSQL 11 and later uses `INCLUDE`. `[teal]`
- MySQL has no `INCLUDE`. You add the extra columns to a composite index instead. `[orange]`

**7. Clustered**

- It defines the physical order of the rows, so a table can have only one.
- In MySQL InnoDB, the primary key is the clustered index. `[orange]`
- PostgreSQL has no real clustered index. The `CLUSTER` command only reorders the table once. `[teal]`

**8. Non-clustered**

- It is a separate structure that points back to the rows. A table can have many.
- MySQL calls it a secondary index.

---

## Slide 5: 7 Common Indexing Mistakes (about 3 minutes)

Here are seven mistakes that people make very often. `[point at the red boxes]`

1. **Many single-column indexes.** If several columns appear together in one query, use one composite index instead.
2. **Wrong column order** in a composite index.
3. **Wrapping an indexed column in a function**, for example `LOWER(email)`. This is the most important one. The index usually stops working. Fix it by rewriting the query, or by creating an expression index.
4. **Too many indexes.** Every write must update all of them, so writes get slower.
5. **No index on a foreign key.** PostgreSQL does not create one for you. MySQL InnoDB does. `[teal / orange]`
6. **Ignoring NULLs.** If most rows are NULL, a partial index is much smaller. It is available in PostgreSQL only. `[teal]`
7. **Never checking whether an index is used.** Look at the system views and drop the indexes nobody uses. In PostgreSQL use `pg_stat_user_indexes`, in MySQL use `sys.schema_unused_indexes`.

---

## Slide 6: How Do I Know an Index Is Used? (about 2 minutes)

The last question: how can you tell that an index is really working? Don't guess. Ask the database.

There are two commands, and they are different:

- `EXPLAIN` shows the **estimated** plan. It does **not** run the query. Use it to see whether an index is used.
- `EXPLAIN ANALYZE` **runs the query for real** and shows the actual number of rows and the actual time.
- Both PostgreSQL and MySQL have both commands. In MySQL, `EXPLAIN ANALYZE` is available from 8.0.18.

How to read the result:

- **PostgreSQL:** `Index Scan` or `Index Only Scan` means an index is used. `Seq Scan` means a full table scan. `[teal]`
- **MySQL:** look at the `key` column, which is the index being used, and the `type` column. `type = ALL` is a full table scan. `ref` or `range` means an index is used. `[orange]`
- A `Seq Scan` is not always a bug. On a small table, or when a query reads most of the table, a full scan is actually the faster choice.

One warning: because `EXPLAIN ANALYZE` really runs the query, be careful with INSERT, UPDATE and DELETE. You can wrap them in a transaction and roll it back.

`[point at the before/after diagram]` Before the index, we see a Seq Scan. After `CREATE INDEX`, we see an Index Scan that touches only the matching rows.

EXPLAIN is a big topic on its own, so today we only covered the basics.

---

## Closing (about 30 seconds)

To summarize:

1. An index makes reads faster and writes slower.
2. Most indexes are B-trees.
3. There are 8 main types. Choose the one that fits your query.
4. Avoid the 7 common mistakes.
5. Always check with `EXPLAIN` instead of guessing.

Thank you. I am happy to take questions now. `[Q&A, no slide]`

---

## Live demo cheat sheet (optional)

Both demo files build the same `users` table with 100,000 rows and walk through the slides in order, with English notes on every statement.

- `demo_mysql.sql`: run it on MySQL 8.0.18 or later.
- `demo_postgres.sql`: run it on PostgreSQL 11 or later.

Good places to stop and show the plan:

| Slide | Statement to run | What to point out |
|---|---|---|
| 4 | `EXPLAIN ... WHERE full_name LIKE 'Nguyen Van 500%'` and `... LIKE '%500'` | Prefix uses the index, leading wildcard does not |
| 4 | `CREATE UNIQUE INDEX ... ON users (province)` | It fails because duplicates already exist |
| 5 | `EXPLAIN ... WHERE YEAR(birth_date) = 1990` (MySQL) / `EXTRACT(YEAR FROM birth_date)` (PostgreSQL) | The function hides the column, so no index is used |
| 6 | `EXPLAIN ANALYZE ... WHERE national_id = '000000050000'` before and after `CREATE INDEX` | Seq Scan or `type = ALL` becomes Index Scan or `type = ref` |
