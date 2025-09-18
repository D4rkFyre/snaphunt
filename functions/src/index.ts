// functions/src/index.ts
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { z } from "zod";

// --- Admin SDK (modular, ESM-friendly) ---
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

// ----------- Secrets / config -----------
// Keep the scorer URL in Secret Manager
const SCORER_URL = defineSecret("SCORER_URL");

// If you ever add an API key later, you can read it from a plain env var:
// const OPTIONAL_API_KEY = process.env.SCORER_API_KEY;

// Init Admin once
if (!getApps().length) {
  initializeApp();
}
const db = getFirestore();

// ----------- Validation schema -----------
const BodySchema = z.object({
  gameId: z.string().min(1),
  submissionId: z.string().min(1),
  hostUrl: z.string().url().startsWith("https://"),
  playerUrl: z.string().url().startsWith("https://"),
});

// ----------- Function -----------
export const scoreSubmission = onRequest(
  {
    timeoutSeconds: 30,
    memory: "256MiB",
    cors: true,
    // Only SCORER_URL is a required secret right now
    secrets: [SCORER_URL],
    region: "us-central1",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send({ error: "Method not allowed" });
        return;
      }

      const parsed = BodySchema.safeParse(req.body);
      if (!parsed.success) {
        res
          .status(400)
          .send({ error: "Invalid request", details: parsed.error.flatten() });
        return;
      }

      const { gameId, submissionId, hostUrl, playerUrl } = parsed.data;

      const scorerUrl = process.env.SCORER_URL;
      if (!scorerUrl) {
        res.status(500).send({ error: "SCORER_URL not configured" });
        return;
      }

      // Call Cloud Run scorer
      const resp = await fetch(`${scorerUrl}/score`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          // If you later add an API key (NOT required now):
          // ...(OPTIONAL_API_KEY ? { "X-API-Key": OPTIONAL_API_KEY } : {}),
        },
        body: JSON.stringify({ host_url: hostUrl, player_url: playerUrl }),
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => "<no body>");
        logger.error("Scorer error", { status: resp.status, text });
        res
          .status(502)
          .send({ error: "Scorer upstream error", status: resp.status, body: text });
        return;
      }

      const data = (await resp.json()) as {
        score: number;
        components: {
          color_ssim: number;
          edge_ssim: number;
          brightness_sim: number;
        };
        diagnostics?: {
          orb_confidence: number;
          orb_inliers: number;
          orb_good_matches: number;
          geom_gate: number;
        };
      };

      // Persist to Firestore
      const subRef = db.doc(`games/${gameId}/submissions/${submissionId}`);
      await subRef.set(
        {
          score: data.score,
          status: "scored",
          components: data.components,
          diagnostics: data.diagnostics ?? null,
          scoredAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      res.status(200).send(data);
    } catch (e: any) {
      logger.error("scoreSubmission failed", e);
      res
        .status(500)
        .send({ error: "Internal error", details: String(e?.message || e) });
    }
  }
);
