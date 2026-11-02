// Which fighters players can pick, as set in the admin portal.
import type { FastifyInstance } from "fastify";
import type { Deps } from "../app.js";

export function rosterRoutes({ db }: Deps) {
  return async (app: FastifyInstance) => {
    app.get("/roster", async () => {
      const { rows } = await db.query<{ id: string }>("SELECT id FROM fighters WHERE unlocked ORDER BY id");
      return { unlocked: rows.map((r) => r.id) };
    });
  };
}
