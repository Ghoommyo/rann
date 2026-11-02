import { describe, expect, it } from "vitest";
import { call, lastCode, signup, useTestApp } from "./helpers.js";

const ctx = useTestApp();

describe("profile", () => {
  it("shows and edits the bio", async () => {
    const { access_token } = await signup(ctx.app, "Mira");
    const me = await call(ctx.app, "GET", "/me", undefined, access_token);
    expect(me.body).toMatchObject({ username: "Mira", bio: "", rating: 1500, games_played: 0, wins: 0, losses: 0, is_active: true });
    const edited = await call(ctx.app, "PATCH", "/me", { bio: "  Tiger and crane.  " }, access_token);
    expect(edited.body.bio).toBe("Tiger and crane.");
    const tooLong = await call(ctx.app, "PATCH", "/me", { bio: "x".repeat(301) }, access_token);
    expect(tooLong.body).toMatchObject({ error: "invalid_input", field: "bio" });
  });

  it("public profiles hide the email", async () => {
    await signup(ctx.app, "Mira");
    const res = await call(ctx.app, "GET", "/users/mira");
    expect(res.status).toBe(200);
    expect(res.body.username).toBe("Mira");
    expect(res.body.email).toBeUndefined();
  });
});

describe("settings", () => {
  it("changes the username, unless taken", async () => {
    const { access_token } = await signup(ctx.app, "Kael");
    await signup(ctx.app, "Mira");
    expect((await call(ctx.app, "PATCH", "/me/username", { username: "MIRA" }, access_token)).body.error).toBe("username_taken");
    const ok = await call(ctx.app, "PATCH", "/me/username", { username: "KaelTheGreat" }, access_token);
    expect(ok.body.username).toBe("KaelTheGreat");
    expect((await call(ctx.app, "POST", "/auth/login", { login: "KaelTheGreat", password: "password123" })).status).toBe(200);
  });

  it("changing the email needs the password and a code sent to the new address", async () => {
    const { access_token } = await signup(ctx.app, "Kael");
    await signup(ctx.app, "Mira");
    const wrong = await call(ctx.app, "PATCH", "/me/email", { email: "new@example.com", password: "nope" }, access_token);
    expect(wrong.body).toMatchObject({ error: "wrong_password", field: "password" });
    const taken = await call(ctx.app, "PATCH", "/me/email", { email: "mira@example.com", password: "password123" }, access_token);
    expect(taken.body).toMatchObject({ error: "email_taken", field: "email" });

    const sent = await call(ctx.app, "PATCH", "/me/email", { email: "New@Example.com", password: "password123" }, access_token);
    expect(sent.body).toEqual({ ok: true, pending_email: "new@example.com" });
    expect(ctx.mailer.outbox.at(-1)!.to).toBe("new@example.com");
    expect((await call(ctx.app, "GET", "/me", undefined, access_token)).body.email).toBe("kael@example.com"); // not yet

    const bad = await call(ctx.app, "POST", "/me/email/confirm", { code: "12345" }, access_token);
    expect(bad.body).toMatchObject({ error: "invalid_input", field: "code" });
    const ok = await call(ctx.app, "POST", "/me/email/confirm", { code: lastCode("new@example.com") }, access_token);
    expect(ok.body).toMatchObject({ email: "new@example.com", email_verified: true });
    expect((await call(ctx.app, "POST", "/auth/login", { login: "new@example.com", password: "password123" })).status).toBe(200);
  });

  it("changing the password needs a code from the account's email", async () => {
    const { access_token } = await signup(ctx.app, "Kael");
    const noCode = await call(ctx.app, "PATCH", "/me/password", { code: "123456", new_password: "brandnew99" }, access_token);
    expect(noCode.body).toMatchObject({ error: "invalid_code", field: "code" });
    const sent = await call(ctx.app, "POST", "/me/password/code", undefined, access_token);
    expect(sent.body).toEqual({ ok: true, email: "kael@example.com" });
    expect(ctx.mailer.outbox.at(-1)!.to).toBe("kael@example.com");
  });

  it("changing the password logs out other devices but keeps this one", async () => {
    const first = await signup(ctx.app, "Kael");
    const other = (await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "password123" })).body;
    await call(ctx.app, "POST", "/me/password/code", undefined, first.access_token);
    const res = await call(ctx.app, "PATCH", "/me/password", { code: lastCode("kael@example.com"), new_password: "brandnew99" }, first.access_token);
    expect(res.status).toBe(200);
    expect(res.body.refresh_token).toBeTruthy();
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token: other.refresh_token })).status).toBe(401);
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token: res.body.refresh_token })).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "brandnew99" })).status).toBe(200);
  });

  it("deactivate hides the account; logging in again can reactivate it", async () => {
    const { access_token } = await signup(ctx.app, "Kael");
    expect((await call(ctx.app, "POST", "/me/deactivate", { password: "wrong" }, access_token)).body.error).toBe("wrong_password");
    expect((await call(ctx.app, "POST", "/me/deactivate", { password: "password123" }, access_token)).status).toBe(200);
    expect((await call(ctx.app, "GET", "/me", undefined, access_token)).status).toBe(401);
    expect((await call(ctx.app, "GET", "/users/kael")).status).toBe(404);

    const blocked = await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "password123" });
    expect(blocked).toMatchObject({ status: 403, body: { error: "account_deactivated" } });
    const back = await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "password123", reactivate: true });
    expect(back.status).toBe(200);
    expect(back.body.user.is_active).toBe(true);
    expect((await call(ctx.app, "GET", "/users/kael")).status).toBe(200);
  });
});
