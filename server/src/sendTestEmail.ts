// Sends one email with the settings in .env, to check that SMTP (Brevo) works:
//   npm run test-email -- you@example.com
import { config } from "./config.js";
import { createMailer } from "./mailer.js";

const to = process.argv[2];
if (!to) {
  console.error("Usage: npm run test-email -- you@example.com");
  process.exit(1);
}
if (!config.smtpUrl) {
  console.log("SMTP_URL isn't set in server/.env, so emails are only printed here (development mode):");
}
try {
  await createMailer(config.smtpUrl, config.mailFrom).send({
    to,
    subject: "Rann test email",
    text: "If you can read this, Rann can send emails (verification codes, password resets).",
  });
  console.log(config.smtpUrl ? `Sent to ${to} from ${config.mailFrom}. Check the inbox (and the spam folder).` : "");
} catch (err) {
  console.error("Sending failed:", (err as Error).message);
  console.error("Check SMTP_URL and MAIL_FROM in server/.env (see server/README.md → Email).");
  process.exit(1);
}
