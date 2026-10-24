import { expect, it } from "vitest";
import { call, useTestApp } from "./helpers.js";

const ctx = useTestApp({ authRateLimit: 3 });

it("limits login attempts per minute", async () => {
  const statuses: number[] = [];
  for (let i = 0; i < 4; i++) {
    statuses.push((await call(ctx.app, "POST", "/auth/login", { login: "x", password: "y" })).status);
  }
  expect(statuses).toEqual([401, 401, 401, 429]);
});
