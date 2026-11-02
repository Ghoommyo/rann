// Makes an admin portal login, or changes its password:
//   npm run create-admin -- you@example.com
// The password is typed here (hidden) and only its hash is stored.
import { createInterface } from "node:readline";
import { emailSchema, passwordSchema } from "./app.js";
import { hashPassword } from "./auth/passwords.js";
import { config } from "./config.js";
import { createDb } from "./db.js";
import { migrate } from "./migrate.js";

// One reader for both questions, so it also works with piped input.
const rl = createInterface({ input: process.stdin, output: process.stdout, terminal: process.stdin.isTTY });
let hiding = "";
// While asking, show only the question, never the typed characters.
const output = rl as unknown as { _writeToOutput: (s: string) => void };
output._writeToOutput = (s: string) => {
  if (!hiding) process.stdout.write(s);
};

const lines = rl[Symbol.asyncIterator](); // keeps lines that arrive early (piped input)

/** Reads a line without showing what's typed. */
async function askHidden(question: string): Promise<string> {
  process.stdout.write(question);
  hiding = question;
  const line = await lines.next();
  hiding = "";
  process.stdout.write("\n");
  return line.done ? "" : line.value;
}

const email = emailSchema.safeParse(process.argv[2] ?? "");
if (!email.success) {
  console.error("Usage: npm run create-admin -- you@example.com");
  process.exit(1);
}
const password = await askHidden("Admin password (at least 8 characters): ");
const problem = passwordSchema.safeParse(password);
if (!problem.success) {
  console.error(problem.error.issues[0]?.message);
  process.exit(1);
}
if ((await askHidden("Type it again: ")) !== password) {
  console.error("The passwords don't match.");
  process.exit(1);
}
rl.close();

const db = createDb(config.databaseUrl);
await migrate(db);
const { rows } = await db.query<{ created: boolean }>(
  `INSERT INTO admins (email, password_hash) VALUES ($1, $2)
   ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash
   RETURNING (xmax = 0) AS created`,
  [email.data, await hashPassword(password)],
);
console.log(rows[0]!.created ? `Admin ${email.data} created.` : `Password changed for admin ${email.data}.`);
console.log(`Log in at http://localhost:${config.port}/admin`);
await db.end();
