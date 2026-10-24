// Every error the API returns has the same shape:
//   { "error": "username_taken", "message": "That username is taken.", "field": "username" }
// `error` is a stable code for the game to react to; `message` is for players.

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly field?: string,
  ) {
    super(message);
  }
}

export const badRequest = (code: string, message: string, field?: string) => new ApiError(400, code, message, field);
export const unauthorized = (message = "Please log in again.") => new ApiError(401, "unauthorized", message);
export const forbidden = (code: string, message: string) => new ApiError(403, code, message);
export const notFound = (message = "Not found.") => new ApiError(404, "not_found", message);
export const conflict = (code: string, message: string, field?: string) => new ApiError(409, code, message, field);
