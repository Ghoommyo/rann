import { describe, expect, it } from "vitest";
import { call, lastCode, signup, useTestApp } from "./helpers.js";

const ctx = useTestApp();

describe("signup", () => {
  it("creates an account that works once the emailed code is entered", async () => {
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "Tulbul", email: "Tulbul@Example.com", password: "password123" });
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ verification_required: true, username: "Tulbul", email: "tulbul@example.com" });
    expect(ctx.mailer.outbox.at(-1)!.subject).toMatch(/^Your Rann code: \d{6}$/);

    const login = await call(ctx.app, "POST", "/auth/login", { login: "Tulbul", password: "password123" });
    expect(login).toMatchObject({ status: 403, body: { error: "email_not_verified" } });

    const verified = await call(ctx.app, "POST", "/auth/verify-email", { login: "tulbul@example.com", code: lastCode("tulbul@example.com") });
    expect(verified.status).toBe(200);
    expect(verified.body.access_token).toBeTruthy();
    expect(verified.body.user).toMatchObject({ username: "Tulbul", email: "tulbul@example.com", email_verified: true, rating: 1500, rank: null });
    expect(verified.body.user.password_hash).toBeUndefined();
    expect((await call(ctx.app, "POST", "/auth/login", { login: "Tulbul", password: "password123" })).status).toBe(200);
  });

  it("rejects a taken username, ignoring case", async () => {
    await signup(ctx.app, "Tulbul");
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "tulbul", email: "other@example.com", password: "password123" });
    expect(res.status).toBe(409);
    expect(res.body).toMatchObject({ error: "username_taken", field: "username" });
  });

  it("rejects a taken email, ignoring case", async () => {
    await signup(ctx.app, "Tulbul", "cop@example.com");
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "Bogembo", email: "COP@example.com", password: "password123" });
    expect(res.status).toBe(409);
    expect(res.body).toMatchObject({ error: "email_taken", field: "email" });
  });

  it("validates fields", async () => {
    const short = await call(ctx.app, "POST", "/auth/signup", { username: "ab", email: "a@b.co", password: "password123" });
    expect(short.body).toMatchObject({ error: "invalid_input", field: "username" });
    const email = await call(ctx.app, "POST", "/auth/signup", { username: "abc", email: "nope", password: "password123" });
    expect(email.body).toMatchObject({ error: "invalid_input", field: "email" });
    const pass = await call(ctx.app, "POST", "/auth/signup", { username: "abc", email: "a@b.co", password: "short" });
    expect(pass.body).toMatchObject({ error: "invalid_input", field: "password" });
  });
});

describe("email verification", () => {
  const start = () => call(ctx.app, "POST", "/auth/signup", { username: "Bogembo", email: "boss@example.com", password: "password123" });

  it("rejects a wrong code, and locks after 5 wrong tries", async () => {
    await start();
    const right = lastCode("boss@example.com");
    const wrong = right === "000000" ? "111111" : "000000";
    const first = await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: wrong });
    expect(first.body).toMatchObject({ error: "invalid_code", field: "code" });
    for (let i = 0; i < 4; i++) await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: wrong });
    expect((await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: right })).body.error).toBe("invalid_code");
  });

  it("resend replaces the old code", async () => {
    await start();
    const old = lastCode("boss@example.com");
    expect((await call(ctx.app, "POST", "/auth/resend-verification", { login: "Bogembo" })).status).toBe(200);
    const fresh = lastCode("boss@example.com");
    if (old !== fresh) {
      expect((await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: old })).body.error).toBe("invalid_code");
    }
    expect((await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: fresh })).status).toBe(200);
  });

  it("an expired code doesn't work", async () => {
    await start();
    await ctx.db.query("UPDATE email_codes SET expires_at = now() - interval '1 minute'");
    expect((await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: lastCode("boss@example.com") })).body.error).toBe("invalid_code");
  });

  it("resend answers the same for unknown or verified accounts and sends nothing", async () => {
    await signup(ctx.app, "Kael");
    const before = ctx.mailer.outbox.length;
    expect((await call(ctx.app, "POST", "/auth/resend-verification", { login: "nobody" })).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/resend-verification", { login: "Kael" })).status).toBe(200);
    expect(ctx.mailer.outbox).toHaveLength(before);
  });

  it("says so when the email can't be sent", async () => {
    const send = ctx.mailer.send;
    ctx.mailer.send = async () => { throw new Error("SMTP down"); };
    const errors = console.error;
    console.error = () => {};
    try {
      expect(await start()).toMatchObject({ status: 503, body: { error: "email_failed" } });
    } finally {
      ctx.mailer.send = send;
      console.error = errors;
    }
    // The account exists, so "Resend code" works once email is back.
    expect((await call(ctx.app, "POST", "/auth/resend-verification", { login: "Bogembo" })).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/verify-email", { login: "Bogembo", code: lastCode("boss@example.com") })).status).toBe(200);
  });
});

describe("login", () => {
  it("works with username or email, any case", async () => {
    await signup(ctx.app, "Ravan", "lanka@example.com");
    for (const login of ["Ravan", "ravan", "lanka@example.com", "LANKA@example.com"]) {
      const res = await call(ctx.app, "POST", "/auth/login", { login, password: "password123" });
      expect(res.status, login).toBe(200);
      expect(res.body.user.username).toBe("Ravan");
    }
  });

  it("rejects a wrong password or unknown user with the same message", async () => {
    await signup(ctx.app, "Ravan");
    const wrong = await call(ctx.app, "POST", "/auth/login", { login: "Ravan", password: "nope12345" });
    const unknown = await call(ctx.app, "POST", "/auth/login", { login: "Nobody", password: "nope12345" });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body.message).toBe(unknown.body.message);
  });
});

describe("sessions", () => {
  it("refresh rotates the token; the old one stops working", async () => {
    const { refresh_token } = await signup(ctx.app, "Mira");
    const first = await call(ctx.app, "POST", "/auth/refresh", { refresh_token });
    expect(first.status).toBe(200);
    expect(first.body.refresh_token).not.toBe(refresh_token);
    const again = await call(ctx.app, "POST", "/auth/refresh", { refresh_token });
    expect(again.status).toBe(401);
  });

  it("logout revokes the refresh token", async () => {
    const { refresh_token } = await signup(ctx.app, "Mira");
    expect((await call(ctx.app, "POST", "/auth/logout", { refresh_token })).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token })).status).toBe(401);
  });

  it("protected routes need a valid token", async () => {
    expect((await call(ctx.app, "GET", "/me")).status).toBe(401);
    expect((await call(ctx.app, "GET", "/me", undefined, "garbage")).status).toBe(401);
  });
});

describe("forgot password", () => {
  const code = () => /code is (\d{6})/.exec(ctx.mailer.outbox.at(-1)!.text)![1]!;

  it("emails a code that resets the password once", async () => {
    await signup(ctx.app, "Kael", "kael@example.com");
    expect((await call(ctx.app, "POST", "/auth/forgot-password", { email: "kael@example.com" })).status).toBe(200);
    expect(ctx.mailer.outbox.at(-1)!.to).toBe("kael@example.com");
    const reset = await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: code(), new_password: "newpassword1" });
    expect(reset.status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "password123" })).status).toBe(401);
    expect((await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "newpassword1" })).status).toBe(200);
    const reuse = await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: code(), new_password: "another123" });
    expect(reuse.body.error).toBe("invalid_code");
  });

  it("answers the same for unknown emails and sends nothing", async () => {
    const res = await call(ctx.app, "POST", "/auth/forgot-password", { email: "nobody@example.com" });
    expect(res.status).toBe(200);
    expect(ctx.mailer.outbox).toHaveLength(0);
  });

  it("locks the code after too many wrong guesses", async () => {
    await signup(ctx.app, "Kael", "kael@example.com");
    await call(ctx.app, "POST", "/auth/forgot-password", { email: "kael@example.com" });
    const right = code();
    const wrong = right === "000000" ? "111111" : "000000";
    for (let i = 0; i < 5; i++) {
      await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: wrong, new_password: "newpassword1" });
    }
    const res = await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: right, new_password: "newpassword1" });
    expect(res.body.error).toBe("invalid_code");
  });

  it("a reset also confirms an unverified email", async () => {
    await call(ctx.app, "POST", "/auth/signup", { username: "Mira", email: "mira@example.com", password: "password123" });
    await call(ctx.app, "POST", "/auth/forgot-password", { email: "mira@example.com" });
    await call(ctx.app, "POST", "/auth/reset-password", { email: "mira@example.com", code: code(), new_password: "newpassword1" });
    expect((await call(ctx.app, "POST", "/auth/login", { login: "Mira", password: "newpassword1" })).status).toBe(200);
  });

  it("logs out all sessions after a reset", async () => {
    const { refresh_token } = await signup(ctx.app, "Kael", "kael@example.com");
    await call(ctx.app, "POST", "/auth/forgot-password", { email: "kael@example.com" });
    await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: code(), new_password: "newpassword1" });
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token })).status).toBe(401);
  });
});
