import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

if (getApps().length === 0) {
  initializeApp();
}

const ANONYMOUS_DAILY_LIMIT = 3;
const LINKED_DAILY_LIMIT = 20;

function dailyLimitFor(signInProvider: string | undefined): number {
  return signInProvider === "anonymous" ? ANONYMOUS_DAILY_LIMIT : LINKED_DAILY_LIMIT;
}

function todayKey(): string {
  return new Date().toISOString().slice(0, 10); // UTC "YYYY-MM-DD"
}

/**
 * Atomically checks and increments the caller's shared daily AI-call quota
 * (analyzeFood + generateRecipe draw from the same counter). Throws
 * HttpsError("resource-exhausted", ...) once the daily limit is reached.
 *
 * Quota is stored server-side under users/{uid}/usage/{date}; Firestore
 * rules deny client writes to that path, so only this function (via the
 * Admin SDK) can move the counter.
 */
export async function checkAndIncrementQuota(
  uid: string,
  signInProvider: string | undefined
): Promise<void> {
  const limit = dailyLimitFor(signInProvider);
  const ref = getFirestore().doc(`users/${uid}/usage/${todayKey()}`);

  await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    if (count >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        `已達每日 ${limit} 次的使用上限，請明天再試，或登入解鎖更多次數。`
      );
    }
    tx.set(ref, { count: count + 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}
