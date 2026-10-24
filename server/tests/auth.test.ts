import { describe, expect, it } from "vitest";
import { call, signup, useTestApp } from "./helpers.js";

const ctx = useTestApp();

describe("signup", () => {
  it("creates an account and logs in", async () => {
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "Tulbul", email: "Tulbul@Example.com", password: "password123" });
    expect(res.status).toBe(201);
    expect(res.body.access_token).toBeTruthy();
    expect(res.body.refresh_token).toBeTruthy();
    expect(res.body.user).toMatchObject({ username: "Tulbul", email: "tulbul@example.com", rating: 1500, games_played: 0, rank: null });
    expect(res.body.user.password_hash).toBeUndefined();
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

  it("logs out all sessions after a reset", async () => {
    const { refresh_token } = await signup(ctx.app, "Kael", "kael@example.com");
    await call(ctx.app, "POST", "/auth/forgot-password", { email: "kael@example.com" });
    await call(ctx.app, "POST", "/auth/reset-password", { email: "kael@example.com", code: code(), new_password: "newpassword1" });
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token })).status).toBe(401);
  });
});
