import { describe, expect, it } from "vitest";
import { call, signup, useTestApp } from "./helpers.js";

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

  it("changing the email needs the password", async () => {
    const { access_token } = await signup(ctx.app, "Kael");
    const wrong = await call(ctx.app, "PATCH", "/me/email", { email: "new@example.com", password: "nope" }, access_token);
    expect(wrong.body).toMatchObject({ error: "wrong_password", field: "password" });
    const ok = await call(ctx.app, "PATCH", "/me/email", { email: "New@Example.com", password: "password123" }, access_token);
    expect(ok.body.email).toBe("new@example.com");
  });

  it("changing the password logs out other devices but keeps this one", async () => {
    const first = await signup(ctx.app, "Kael");
    const other = (await call(ctx.app, "POST", "/auth/login", { login: "Kael", password: "password123" })).body;
    const res = await call(ctx.app, "PATCH", "/me/password", { current_password: "password123", new_password: "brandnew99" }, first.access_token);
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
