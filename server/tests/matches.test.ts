import { describe, expect, it } from "vitest";
import { resolveStaleMatches, REPORT_WINDOW_MS } from "../src/matches.js";
import { call, signup, useTestApp } from "./helpers.js";

const ctx = useTestApp();

async function twoPlayers() {
  const host = await signup(ctx.app, "Host");
  const guest = await signup(ctx.app, "Guest");
  const created = await call(ctx.app, "POST", "/matches", { opponent: "guest", my_character: "kael", opponent_character: "mira" }, host.access_token);
  expect(created.status).toBe(201);
  return { host: host.access_token, guest: guest.access_token, id: created.body.match_id as string };
}

const profile = async (name: string) => (await call(ctx.app, "GET", `/users/${name}`)).body;

describe("ranked matches", () => {
  it("both players agree → ratings and stats update", async () => {
    const { host, guest, id } = await twoPlayers();
    const first = await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, host);
    expect(first.body.status).toBe("pending");
    const second = await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, guest);
    expect(second.body).toMatchObject({ status: "confirmed", result: "p1", you_are: "p2" });
    expect(second.body.rating_change).toBeLessThan(0);

    const winner = await profile("host");
    const loser = await profile("guest");
    expect(winner).toMatchObject({ games_played: 1, wins: 1, losses: 0, rank: 1 });
    expect(loser).toMatchObject({ games_played: 1, wins: 0, losses: 1, rank: 2 });
    expect(winner.rating).toBeGreaterThan(1500);
    expect(loser.rating).toBeLessThan(1500);

    const board = await call(ctx.app, "GET", "/leaderboard");
    expect(board.body.players.map((p: { username: string }) => p.username)).toEqual(["Host", "Guest"]);
  });

  it("disagreeing reports → disputed, nothing changes", async () => {
    const { host, guest, id } = await twoPlayers();
    await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, host);
    const res = await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p2" }, guest);
    expect(res.body.status).toBe("disputed");
    expect((await profile("host")).games_played).toBe(0);
    expect((await profile("guest")).rating).toBe(1500);
  });

  it("a player who leaves without reporting still gets the result", async () => {
    const { host, id } = await twoPlayers();
    await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, host);
    expect(await resolveStaleMatches(ctx.db, new Date())).toEqual({ confirmed: 0, expired: 0 }); // too early
    const later = new Date(Date.now() + REPORT_WINDOW_MS + 1000);
    expect(await resolveStaleMatches(ctx.db, later)).toMatchObject({ confirmed: 1 });
    expect(await profile("guest")).toMatchObject({ games_played: 1, losses: 1 });
  });

  it("only the two players can report, once each", async () => {
    const { host, id } = await twoPlayers();
    const outsider = await signup(ctx.app, "Outsider");
    expect((await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p2" }, outsider.access_token)).status).toBe(403);
    await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, host);
    expect((await call(ctx.app, "POST", `/matches/${id}/result`, { result: "p1" }, host)).body.error).toBe("already_reported");
  });

  it("can't open a match against yourself or a missing player", async () => {
    const { access_token } = await signup(ctx.app, "Solo");
    expect((await call(ctx.app, "POST", "/matches", { opponent: "solo" }, access_token)).body.error).toBe("self_match");
    expect((await call(ctx.app, "POST", "/matches", { opponent: "ghost" }, access_token)).status).toBe(404);
  });

  it("a draw counts as a draw for both", async () => {
    const { host, guest, id } = await twoPlayers();
    await call(ctx.app, "POST", `/matches/${id}/result`, { result: "draw" }, host);
    await call(ctx.app, "POST", `/matches/${id}/result`, { result: "draw" }, guest);
    expect(await profile("host")).toMatchObject({ games_played: 1, draws: 1, rating: 1500 });
  });
});
