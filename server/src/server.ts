// Starts the API:  npm run dev  (development)  ·  npm start  (after npm run build)
import { buildApp } from "./app.js";
import { config } from "./config.js";
import { createDb } from "./db.js";
import { createMailer } from "./mailer.js";
import { resolveStaleMatches } from "./matches.js";
import { migrate } from "./migrate.js";

const db = createDb(config.databaseUrl);
await migrate(db, (msg) => console.log(`[migrate] ${msg}`));
const app = await buildApp({
  db,
  mailer: createMailer(config.smtpUrl, config.mailFrom),
  jwtSecret: config.jwtSecret,
  corsOrigins: config.corsOrigins,
  logger: true,
});

// Settle ranked matches where only one player reported (the other left).
const sweeper = setInterval(() => {
  resolveStaleMatches(db).catch((err) => app.log.error(err));
}, 30_000);

const shutdown = async () => {
  clearInterval(sweeper);
  await app.close();
  await db.end();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

await app.listen({ port: config.port, host: config.host });
