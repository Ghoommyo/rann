// Ranked online matches: the host opens one, both players report the result.
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { parse, requireUserId, type Deps } from "../app.js";
import { forbidden, notFound, unauthorized } from "../errors.js";
import { createMatch, submitReport, type MatchRow } from "../matches.js";
import { findUserById } from "../users.js";

const idSchema = z.object({ id: z.uuid("No such match.") });

function view(match: MatchRow, userId: string) {
  const me = match.player1_id === userId ? "p1" : "p2";
  const change = me === "p1" ? match.p1_rating_change : match.p2_rating_change;
  return {
    match_id: match.id,
    you_are: me,
    status: match.status,
    result: match.result,
    rating_change: change === null ? null : Math.round(change),
  };
}

export function matchRoutes({ db }: Deps) {
  return async (app: FastifyInstance) => {
    app.post("/", async (req, reply) => {
      const userId = await requireUserId(req);
      const me = await findUserById(db, userId);
      if (!me || !me.is_active) throw unauthorized();
      const body = parse(
        z.object({
          opponent: z.string().trim().min(1),
          my_character: z.string().max(40).default(""),
          opponent_character: z.string().max(40).default(""),
        }),
        req.body,
      );
      const id = await createMatch(db, userId, body.opponent, body.my_character, body.opponent_character);
      reply.status(201);
      return { match_id: id };
    });

    app.post("/:id/result", async (req) => {
      const userId = await requireUserId(req);
      const { id } = parse(idSchema, req.params);
      const { result } = parse(z.object({ result: z.enum(["p1", "p2", "draw"]) }), req.body);
      return view(await submitReport(db, id, userId, result), userId);
    });

    app.get("/:id", async (req) => {
      const userId = await requireUserId(req);
      const { id } = parse(idSchema, req.params);
      const { rows } = await db.query<MatchRow>("SELECT * FROM matches WHERE id = $1", [id]);
      const match = rows[0];
      if (!match) throw notFound("No such match.");
      if (match.player1_id !== userId && match.player2_id !== userId) throw forbidden("not_a_player", "You didn't play in this match.");
      return view(match, userId);
    });
  };
}
