/* eslint-disable no-console */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Callable function from the Flutter app to increment viewsCount
 * for a given event.
 *
 * In Flutter we call it with:
 * FirebaseFunctions.instance
 *   .httpsCallable('incrementEventView')
 *   .call({'eventId': eventId});
 */
exports.incrementEventView = functions.https.onCall(
    async (data, context) => {
        if (!context.auth) {
            throw new functions.https.HttpsError(
                "unauthenticated",
                "Sign in first."
            );
        }

        const eventId = data.eventId;
        if (!eventId) {
            throw new functions.https.HttpsError(
                "invalid-argument",
                "eventId is required"
            );
        }

        const ref = db.collection("events").doc(eventId);
        await ref.update({
            viewsCount: admin.firestore.FieldValue.increment(1),
        });

        return {ok: true};
    }
);

/**
 * Firestore trigger:
 * Keeps events/{eventId}.likesCount in sync with
 * documents under events/{eventId}/likes/{userId}.
 */
exports.onLikeWrite = functions.firestore
    .document("events/{eventId}/likes/{userId}")
    .onWrite(async (change, context) => {
        const eventRef =
      db.collection("events").doc(context.params.eventId);

        let inc = 0;
        if (!change.before.exists && change.after.exists) {
            // new like
            inc = 1;
        } else if (change.before.exists && !change.after.exists) {
            // unlike
            inc = -1;
        } else {
            // updated like doc – ignore
            return null;
        }

        await eventRef.update({
            likesCount: admin.firestore.FieldValue.increment(inc),
        });

        return null;
    });

/**
 * Firestore trigger:
 * Keeps events/{eventId}.commentsCount in sync with
 * documents under events/{eventId}/comments/{commentId}.
 */
exports.onCommentWrite = functions.firestore
    .document("events/{eventId}/comments/{commentId}")
    .onWrite(async (change, context) => {
        const eventRef =
      db.collection("events").doc(context.params.eventId);

        let inc = 0;
        if (!change.before.exists && change.after.exists) {
            // new comment
            inc = 1;
        } else if (change.before.exists && !change.after.exists) {
            // deleted comment
            inc = -1;
        } else {
            // updated comment – ignore
            return null;
        }

        await eventRef.update({
            commentsCount: admin.firestore.FieldValue.increment(inc),
        });

        return null;
    });


