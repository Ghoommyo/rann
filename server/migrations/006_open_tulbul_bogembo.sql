-- Tulbul Pandey and Bogembo are ready: open them for everyone.
-- (The admin can still lock them again in the portal → Players.)
UPDATE fighters SET unlocked = true, updated_at = now() WHERE id IN ('tulbul_pandey', 'bogembo');
