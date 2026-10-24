// Applies migrations/*.sql in name order, each once, each in a transaction.
//   npm run migrate            → the dev database (DATABASE_URL)
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { config } from "./config.js";
import { createDb, transaction, type Db } from "./db.js";

const dir = fileURLToPath(new URL("../migrations/", import.meta.url));

export async function migrate(db: Db, log: (msg: string) => void = () => {}): Promise<void> {
  await db.query("CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())");
  const done = new Set((await db.query<{ name: string }>("SELECT name FROM schema_migrations")).rows.map((r) => r.name));
  for (const file of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
    if (done.has(file)) continue;
    const sql = readFileSync(dir + file, "utf8");
    await transaction(db, async (client) => {
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
    });
    log(`applied ${file}`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const db = createDb(config.databaseUrl);
  migrate(db, console.log)
    .then(() => console.log("migrations up to date"))
    .finally(() => db.end());
}
