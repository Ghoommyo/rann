import { describe, expect, it } from "vitest";
import { DEFAULT_RATING, updateRating } from "../src/rating/glicko2.js";

describe("Glicko-2", () => {
  it("matches the worked example in Glickman's paper", () => {
    const result = updateRating({ rating: 1500, deviation: 200, volatility: 0.06 }, [
      { opponent: { rating: 1400, deviation: 30, volatility: 0.06 }, score: 1 },
      { opponent: { rating: 1550, deviation: 100, volatility: 0.06 }, score: 0 },
      { opponent: { rating: 1700, deviation: 300, volatility: 0.06 }, score: 0 },
    ]);
    expect(result.rating).toBeCloseTo(1464.06, 1);
    expect(result.deviation).toBeCloseTo(151.52, 1);
    expect(result.volatility).toBeCloseTo(0.05999, 4);
  });

  it("a win raises the winner and lowers the loser by the same amount for equal players", () => {
    const winner = updateRating(DEFAULT_RATING, [{ opponent: DEFAULT_RATING, score: 1 }]);
    const loser = updateRating(DEFAULT_RATING, [{ opponent: DEFAULT_RATING, score: 0 }]);
    expect(winner.rating).toBeGreaterThan(1500);
    expect(loser.rating).toBeLessThan(1500);
    expect(winner.rating - 1500).toBeCloseTo(1500 - loser.rating, 6);
    expect(winner.deviation).toBeLessThan(350); // more certain after a game
  });

  it("beating a stronger player gains more than beating a weaker one", () => {
    const me = { rating: 1500, deviation: 100, volatility: 0.06 };
    const vsStrong = updateRating(me, [{ opponent: { ...me, rating: 1800 }, score: 1 }]);
    const vsWeak = updateRating(me, [{ opponent: { ...me, rating: 1200 }, score: 1 }]);
    expect(vsStrong.rating - 1500).toBeGreaterThan(vsWeak.rating - 1500);
  });

  it("a draw between equal players leaves the rating unchanged", () => {
    const result = updateRating(DEFAULT_RATING, [{ opponent: DEFAULT_RATING, score: 0.5 }]);
    expect(result.rating).toBeCloseTo(1500, 6);
  });
});
