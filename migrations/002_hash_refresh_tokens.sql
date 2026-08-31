UPDATE refresh_tokens
SET token = SHA2(token, 256)
WHERE CHAR_LENGTH(token) <> 64;

