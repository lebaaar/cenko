/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions/v2/options";
import {HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

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

export const deleteMyAccount = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to delete an account.");
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const auth = getAuth();

  // Fetch all list memberships for this user
  const membershipsSnap = await db
    .collection("users").doc(uid)
    .collection("shopping_lists_memberships")
    .get();

  const listIds = membershipsSnap.docs.map((d) => d.id);

  const listDocs = listIds.length > 0
    ? await Promise.all(listIds.map((id) => db.collection("shopping_lists").doc(id).get()))
    : [];

  // Block if user owns any shared list (other members present)
  const ownedSharedLists: string[] = [];
  for (const doc of listDocs) {
    if (!doc.exists) continue;
    const data = doc.data()!;
    const members: Array<{user_id: string}> = data.members ?? [];
    if (data.owner_id === uid && members.some((m) => m.user_id !== uid)) {
      ownedSharedLists.push(data.name as string);
    }
  }

  if (ownedSharedLists.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      "Cannot delete account while owning shared lists",
      {ownedLists: ownedSharedLists},
    );
  }

  // Delete private lists (owned, no other members) and remove from shared lists
  const memberBatch = db.batch();
  let hasMemberUpdates = false;

  for (const doc of listDocs) {
    if (!doc.exists) continue;
    const data = doc.data()!;
    if (data.owner_id === uid) {
      await db.recursiveDelete(doc.ref);
    } else {
      const members: Array<{user_id: string}> = data.members ?? [];
      memberBatch.update(doc.ref, {
        members: members.filter((m) => m.user_id !== uid),
        member_uids: FieldValue.arrayRemove(uid),
      });
      hasMemberUpdates = true;
    }
  }

  if (hasMemberUpdates) await memberBatch.commit();

  // Delete all invitations related to this user (sent or received)
  const [receivedInvSnap, sentInvSnap] = await Promise.all([
    db
      .collection("shopping_list_invitations")
      .where("invited_uid", "==", uid)
      .get(),

    db
      .collection("shopping_list_invitations")
      .where("invited_by_user_id", "==", uid)
      .get(),
  ]);

  const invBatch = db.batch();
  let hasInvDeletes = false;

  // Invitations received
  for (const doc of receivedInvSnap.docs) {
    invBatch.delete(doc.ref);
    hasInvDeletes = true;
  }

  // Invitations sent
  for (const doc of sentInvSnap.docs) {
    invBatch.delete(doc.ref);
    hasInvDeletes = true;
  }

  if (hasInvDeletes) {
    await invBatch.commit();
  }

  // Delete user document tree and auth account
  await db.recursiveDelete(db.collection("users").doc(uid));
  await auth.deleteUser(uid);

  logger.info("Deleted user account data", {uid, structuredData: true});
  return {success: true};
});
