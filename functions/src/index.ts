/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions/v2/options";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });
initializeApp();

export const helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase!");
});

export const getTestText = onCall(() => {
  const text = "Firebase function call works.";
  logger.info("Returning test text", {text, structuredData: true});
  return {text};
});

export const deleteMyAccount = onCall(async (request) => {
  const idToken = typeof request.data?.idToken === "string" ? request.data.idToken : null;
  const db = getFirestore();
  const auth = getAuth();

  let uid = request.auth?.uid ?? null;
  if (!uid && idToken) {
    const decoded = await auth.verifyIdToken(idToken, true);
    uid = decoded.uid;
  }

  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to delete an account.");
  }

  const userRef = db.collection("users").doc(uid);

  await db.recursiveDelete(userRef);
  await auth.deleteUser(uid);

  logger.info("Deleted user account data", {uid, structuredData: true});
  return {success: true};
});
