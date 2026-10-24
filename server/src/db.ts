// PostgreSQL access: one pool per app, plus a transaction helper.
import pg from "pg";

export type Db = pg.Pool;
export type Queryable = pg.Pool | pg.PoolClient;

export function createDb(connectionString: string): Db {
  return new pg.Pool({ connectionString, max: 10 });
}

/** Runs `fn` inside BEGIN/COMMIT, rolling back if it throws. */
export async function transaction<T>(db: Db, fn: (client: pg.PoolClient) => Promise<T>): Promise<T> {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
