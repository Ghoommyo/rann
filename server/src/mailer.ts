// Sends emails. Without SMTP_URL (development and tests) emails are printed
// to the console and kept in `outbox` instead of being sent.
import nodemailer from "nodemailer";

export interface Mail {
  to: string;
  subject: string;
  text: string;
}

export interface Mailer {
  send(mail: Mail): Promise<void>;
  /** Emails "sent" without SMTP, newest last (for development and tests). */
  outbox: Mail[];
}

export function createMailer(smtpUrl: string, from: string, log: (msg: string) => void = console.log): Mailer {
  const outbox: Mail[] = [];
  if (!smtpUrl) {
    return {
      outbox,
      async send(mail) {
        outbox.push(mail);
        log(`[email to ${mail.to}] ${mail.subject}\n${mail.text}`);
      },
    };
  }
  const transport = nodemailer.createTransport(smtpUrl);
  return {
    outbox,
    async send(mail) {
      await transport.sendMail({ from, ...mail });
    },
  };
}
