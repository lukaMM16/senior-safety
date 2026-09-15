const {setGlobalOptions} = require("firebase-functions");
const {
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");

const logger = require("firebase-functions/logger");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

setGlobalOptions({
  maxInstances: 10,
});

exports.sendHelpNotification = onDocumentCreated(
    {
      document:
        "families/{familyCode}/help_requests/{requestId}",
      region: "europe-west3",
    },
    async (event) => {
      const familyCode = event.params.familyCode;
      const requestId = event.params.requestId;

      logger.info("Novi zahtjev za pomoć.", {
        familyCode: familyCode,
        requestId: requestId,
      });

      const membersSnapshot = await getFirestore()
          .collection("families")
          .doc(familyCode)
          .collection("members")
          .get();

      if (membersSnapshot.empty) {
        logger.warn(
            "Obitelj nema registriranih članova.",
            {
              familyCode: familyCode,
            },
        );
        return;
      }

      const tokens = [];

      membersSnapshot.forEach((document) => {
        const data = document.data();

        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      if (tokens.length === 0) {
        logger.warn(
            "Nisu pronađeni FCM tokeni.",
            {
              familyCode: familyCode,
            },
        );
        return;
      }

      const message = {
        tokens: tokens,

        data: {
          type: "help_request",
          title: "🚨 Senior Safety",
          body: "Starija osoba treba pomoć!",
          familyCode: familyCode,
          requestId: requestId,
        },

        android: {
          priority: "high",
          ttl: 60000,
        },
      };

      try {
        const response =
          await getMessaging().sendEachForMulticast(
              message,
          );

        logger.info(
            "Push obavijesti obrađene.",
            {
              familyCode: familyCode,
              requestId: requestId,
              successCount:
                response.successCount,
              failureCount:
                response.failureCount,
            },
        );

        response.responses.forEach(
            (result, index) => {
              if (!result.success) {
                logger.error(
                    "Greška pri slanju na uređaj.",
                    {
                      tokenIndex: index,
                      error: result.error ?
                        result.error.message :
                        "Nepoznata greška",
                    },
                );
              }
            },
        );
      } catch (error) {
        logger.error(
            "Greška pri slanju push obavijesti.",
            error,
        );

        throw error;
      }
    },
);
