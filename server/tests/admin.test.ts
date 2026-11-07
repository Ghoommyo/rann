// The admin portal API: its own logins, analytics, and switching users and
// fighters on and off.
import { describe, expect, it } from "vitest";
import { hashPassword } from "../src/auth/passwords.js";
import { call, signup, useTestApp } from "./helpers.js";

const ctx = useTestApp();

async function adminToken(email = "boss@example.com", password = "admin-pass-1") {
  await ctx.db.query("INSERT INTO admins (email, password_hash) VALUES ($1, $2) ON CONFLICT DO NOTHING", [email, await hashPassword(password)]);
  const res = await call(ctx.app, "POST", "/admin/api/login", { email, password });
  expect(res.status).toBe(200);
  return res.body.token as string;
}

async function userId(username: string): Promise<string> {
  const { rows } = await ctx.db.query<{ id: string }>("SELECT id FROM users WHERE username = $1", [username]);
  return rows[0]!.id;
}

describe("admin login", () => {
  it("works with the admin's email and password, case-insensitive email", async () => {
    await adminToken();
    const res = await call(ctx.app, "POST", "/admin/api/login", { email: "BOSS@example.com", password: "admin-pass-1" });
    expect(res.status).toBe(200);
    expect(res.body.email).toBe("boss@example.com");
    expect((await call(ctx.app, "GET", "/admin/api/me", undefined, res.body.token)).body.email).toBe("boss@example.com");
  });

  it("refuses a wrong password, an unknown email and a game account", async () => {
    await adminToken();
    await signup(ctx.app, "player1");
    for (const body of [
      { email: "boss@example.com", password: "nope-nope" },
      { email: "nobody@example.com", password: "admin-pass-1" },
      { email: "player1@example.com", password: "password123" },
    ]) {
      const res = await call(ctx.app, "POST", "/admin/api/login", body);
      expect(res.status).toBe(401);
      expect(res.body.message).toBe("Wrong email or password.");
    }
  });

  it("keeps admin and player tokens apart", async () => {
    const admin = await adminToken();
    const player = await signup(ctx.app, "player1");
    expect((await call(ctx.app, "GET", "/admin/api/stats", undefined, player.access_token)).status).toBe(401);
    expect((await call(ctx.app, "GET", "/admin/api/stats")).status).toBe(401);
    expect((await call(ctx.app, "GET", "/me", undefined, admin)).status).toBe(401);
  });

  it("stops working when the admin is removed", async () => {
    const admin = await adminToken();
    await ctx.db.query("DELETE FROM admins");
    expect((await call(ctx.app, "GET", "/admin/api/me", undefined, admin)).status).toBe(401);
  });
});

describe("admin stats", () => {
  it("counts users and matches", async () => {
    const admin = await adminToken();
    await signup(ctx.app, "alice");
    const bob = await signup(ctx.app, "bob");
    await call(ctx.app, "POST", "/me/deactivate", { password: "password123" }, bob.access_token);
    const res = await call(ctx.app, "GET", "/admin/api/stats", undefined, admin);
    expect(res.status).toBe(200);
    expect(res.body.users).toMatchObject({ total: 2, active: 1, inactive: 1, verified: 2, new_7d: 2 });
    expect(res.body.matches.total).toBe(0);
    expect(res.body.signups_per_day).toHaveLength(30);
    expect(res.body.signups_per_day.at(-1).count).toBe(2);
    expect(res.body.players_per_day.at(-1).count).toBe(2);
  });
});

describe("admin users", () => {
  it("lists active and inactive users, with search", async () => {
    const admin = await adminToken();
    await signup(ctx.app, "alice");
    await signup(ctx.app, "albert");
    const bob = await signup(ctx.app, "bob");
    await call(ctx.app, "POST", "/me/deactivate", { password: "password123" }, bob.access_token);

    const active = await call(ctx.app, "GET", "/admin/api/users?status=active", undefined, admin);
    expect(active.body.total).toBe(2);
    expect(active.body.users.map((u: { username: string }) => u.username).sort()).toEqual(["albert", "alice"]);
    const inactive = await call(ctx.app, "GET", "/admin/api/users?status=inactive", undefined, admin);
    expect(inactive.body.users).toMatchObject([{ username: "bob", status: "deactivated" }]);
    const search = await call(ctx.app, "GET", "/admin/api/users?q=ALIC", undefined, admin);
    expect(search.body.users.map((u: { username: string }) => u.username)).toEqual(["alice"]);
    expect((await call(ctx.app, "GET", "/admin/api/users?q=%25", undefined, admin)).body.total).toBe(0);
  });

  it("switching a user off logs them out and they can't come back until switched on", async () => {
    const admin = await adminToken();
    const alice = await signup(ctx.app, "alice");
    const id = await userId("alice");

    expect((await call(ctx.app, "POST", `/admin/api/users/${id}/disable`, {}, admin)).status).toBe(200);
    expect((await call(ctx.app, "GET", "/me", undefined, alice.access_token)).status).toBe(401);
    expect((await call(ctx.app, "POST", "/auth/refresh", { refresh_token: alice.refresh_token })).status).toBe(401);
    const login = await call(ctx.app, "POST", "/auth/login", { login: "alice", password: "password123", reactivate: true });
    expect(login.status).toBe(403);
    expect(login.body.error).toBe("account_disabled");
    expect((await call(ctx.app, "GET", "/users/alice")).status).toBe(404);
    const listed = await call(ctx.app, "GET", "/admin/api/users?status=inactive", undefined, admin);
    expect(listed.body.users[0].status).toBe("disabled");

    expect((await call(ctx.app, "POST", `/admin/api/users/${id}/enable`, {}, admin)).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/login", { login: "alice", password: "password123" })).status).toBe(200);
  });

  it("404s for an unknown user", async () => {
    const admin = await adminToken();
    expect((await call(ctx.app, "POST", "/admin/api/users/00000000-0000-0000-0000-000000000000/disable", {}, admin)).status).toBe(404);
    expect((await call(ctx.app, "POST", "/admin/api/users/not-a-uuid/disable", {}, admin)).status).toBe(400);
  });
});

describe("fighters and the roster", () => {
  it("starts with Kael and Mira open", async () => {
    expect((await call(ctx.app, "GET", "/roster")).body).toEqual({ unlocked: ["kael", "mira"] });
  });

  it("the admin opens and locks fighters for everyone", async () => {
    const admin = await adminToken();
    const all = await call(ctx.app, "GET", "/admin/api/fighters", undefined, admin);
    expect(all.body.fighters).toHaveLength(6);
    expect((await call(ctx.app, "PATCH", "/admin/api/fighters/tulbul_pandey", { unlocked: true }, admin)).body.unlocked).toBe(true);
    await call(ctx.app, "PATCH", "/admin/api/fighters/mira", { unlocked: false }, admin);
    expect((await call(ctx.app, "GET", "/roster")).body).toEqual({ unlocked: ["kael", "tulbul_pandey"] });
    expect((await call(ctx.app, "PATCH", "/admin/api/fighters/nobody", { unlocked: true }, admin)).status).toBe(404);
  });

  it("refuses players", async () => {
    const player = await signup(ctx.app, "player1");
    expect((await call(ctx.app, "PATCH", "/admin/api/fighters/ravan", { unlocked: true }, player.access_token)).status).toBe(401);
  });
});

describe("portal pages", () => {
  it("are served at /admin", async () => {
    expect((await ctx.app.inject({ url: "/admin" })).statusCode).toBe(302);
    const page = await ctx.app.inject({ url: "/admin/" });
    expect(page.statusCode).toBe(200);
    expect(page.headers["content-type"]).toContain("text/html");
  });
});

describe("admin settings", () => {
  it("email verification is required by default", async () => {
    const admin = await adminToken();
    expect((await call(ctx.app, "GET", "/admin/api/settings", undefined, admin)).body).toEqual({ email_verification_required: true });
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "newbie", email: "newbie@example.com", password: "password123" });
    expect(res.body.verification_required).toBe(true);
    expect(res.body.access_token).toBeUndefined();
  });

  it("when switched off, sign-up logs in straight away and no code is needed", async () => {
    const admin = await adminToken();
    const changed = await call(ctx.app, "PATCH", "/admin/api/settings", { email_verification_required: false }, admin);
    expect(changed.body.email_verification_required).toBe(false);
    const res = await call(ctx.app, "POST", "/auth/signup", { username: "newbie", email: "newbie@example.com", password: "password123" });
    expect(res.status).toBe(201);
    expect(res.body.verification_required).toBe(false);
    expect(res.body.user.email_verified).toBe(false);
    expect(ctx.mailer.outbox).toHaveLength(0);
    expect((await call(ctx.app, "GET", "/me", undefined, res.body.access_token)).status).toBe(200);
    expect((await call(ctx.app, "POST", "/auth/login", { login: "newbie", password: "password123" })).status).toBe(200);
  });

  it("switching it back on asks unconfirmed players for a code again", async () => {
    const admin = await adminToken();
    await call(ctx.app, "PATCH", "/admin/api/settings", { email_verification_required: false }, admin);
    await call(ctx.app, "POST", "/auth/signup", { username: "newbie", email: "newbie@example.com", password: "password123" });
    await call(ctx.app, "PATCH", "/admin/api/settings", { email_verification_required: true }, admin);
    const login = await call(ctx.app, "POST", "/auth/login", { login: "newbie", password: "password123" });
    expect(login.body.error).toBe("email_not_verified");
  });

  it("only admins change settings, and unknown settings are refused", async () => {
    const player = await signup(ctx.app, "player1");
    expect((await call(ctx.app, "PATCH", "/admin/api/settings", { email_verification_required: false }, player.access_token)).status).toBe(401);
    const admin = await adminToken();
    expect((await call(ctx.app, "PATCH", "/admin/api/settings", { something_else: 1 }, admin)).status).toBe(400);
  });
});
