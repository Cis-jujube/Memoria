import { pbkdf2Sync, randomBytes, timingSafeEqual } from "crypto";

const algorithm = "pbkdf2_sha256";
const iterations = 210_000;
const keyLength = 32;
const digest = "sha256";

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function isValidPassword(password: string) {
  return password.length >= 8;
}

export function hashPassword(password: string) {
  const salt = randomBytes(16).toString("base64url");
  const hash = derive(password, salt).toString("base64url");
  return `${algorithm}$${iterations}$${salt}$${hash}`;
}

export function verifyPassword(password: string, storedHash: string | null | undefined) {
  if (!storedHash) return false;

  const [storedAlgorithm, iterationText, salt, hash] = storedHash.split("$");
  const parsedIterations = Number(iterationText);

  if (
    storedAlgorithm !== algorithm ||
    parsedIterations !== iterations ||
    !salt ||
    !hash
  ) {
    return false;
  }

  const expected = Buffer.from(hash, "base64url");
  const actual = derive(password, salt);

  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function derive(password: string, salt: string) {
  return pbkdf2Sync(password, salt, iterations, keyLength, digest);
}
