// Glicko-2 rating system (Mark Glickman, http://www.glicko.net/glicko/glicko2.pdf),
// the system chess.com uses.
//
// Each player has a rating (≈1500 for a newcomer), a rating deviation (RD:
// how unsure we are; it shrinks as they play) and a volatility (how erratic
// their results are). A win against a stronger player gains more than a win
// against a weaker one, and new players' ratings move faster.

export interface Rating {
  rating: number;
  deviation: number;
  volatility: number;
}

export interface GameResult {
  opponent: Rating;
  /** 1 = win, 0.5 = draw, 0 = loss */
  score: number;
}

export const DEFAULT_RATING: Rating = { rating: 1500, deviation: 350, volatility: 0.06 };

/** System constant: how much volatility can change (Glickman suggests 0.3–1.2). */
const TAU = 0.5;
const SCALE = 173.7178;
const EPSILON = 0.000001;

const g = (phi: number) => 1 / Math.sqrt(1 + (3 * phi * phi) / (Math.PI * Math.PI));
const expected = (mu: number, muJ: number, phiJ: number) => 1 / (1 + Math.exp(-g(phiJ) * (mu - muJ)));

/** The player's new rating after the games of one rating period. */
export function updateRating(player: Rating, games: GameResult[]): Rating {
  // Step 2: convert to the Glicko-2 scale.
  const mu = (player.rating - 1500) / SCALE;
  const phi = player.deviation / SCALE;
  const sigma = player.volatility;

  if (games.length === 0) {
    // Step 6 only: unsure-ness grows when a player doesn't play.
    const phiStar = Math.sqrt(phi * phi + sigma * sigma);
    return { rating: player.rating, deviation: phiStar * SCALE, volatility: sigma };
  }

  const opponents = games.map((game) => ({
    mu: (game.opponent.rating - 1500) / SCALE,
    phi: game.opponent.deviation / SCALE,
    score: game.score,
  }));

  // Step 3: estimated variance from game outcomes alone.
  let vInverse = 0;
  // Step 4: estimated improvement.
  let deltaSum = 0;
  for (const o of opponents) {
    const e = expected(mu, o.mu, o.phi);
    vInverse += g(o.phi) ** 2 * e * (1 - e);
    deltaSum += g(o.phi) * (o.score - e);
  }
  const v = 1 / vInverse;
  const delta = v * deltaSum;

  // Step 5: new volatility (Illinois algorithm).
  const a = Math.log(sigma * sigma);
  const f = (x: number) => {
    const ex = Math.exp(x);
    return (ex * (delta * delta - phi * phi - v - ex)) / (2 * (phi * phi + v + ex) ** 2) - (x - a) / (TAU * TAU);
  };
  let A = a;
  let B: number;
  if (delta * delta > phi * phi + v) {
    B = Math.log(delta * delta - phi * phi - v);
  } else {
    let k = 1;
    while (f(a - k * TAU) < 0) k++;
    B = a - k * TAU;
  }
  let fA = f(A);
  let fB = f(B);
  while (Math.abs(B - A) > EPSILON) {
    const C = A + ((A - B) * fA) / (fB - fA);
    const fC = f(C);
    if (fC * fB <= 0) {
      A = B;
      fA = fB;
    } else {
      fA /= 2;
    }
    B = C;
    fB = fC;
  }
  const newSigma = Math.exp(A / 2);

  // Steps 6–7: new deviation and rating.
  const phiStar = Math.sqrt(phi * phi + newSigma * newSigma);
  const newPhi = 1 / Math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  const newMu = mu + newPhi * newPhi * deltaSum;

  // Step 8: back to the familiar scale.
  return { rating: newMu * SCALE + 1500, deviation: newPhi * SCALE, volatility: newSigma };
}
