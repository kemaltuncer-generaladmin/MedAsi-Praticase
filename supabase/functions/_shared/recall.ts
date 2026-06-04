type JsonMap = Record<string, unknown>;

type EdgeRuntimeWithWaitUntil = {
  waitUntil?: (promise: Promise<unknown>) => void;
};

type RecallEvent = {
  source_app: "praticase";
  event_type:
    | "case_completed"
    | "clinical_weakness"
    | "oral_exam_feedback"
    | "oral_exam_weakness"
    | "osce_station_weakness"
    | "case_saved_for_retry";
  title?: string;
  subject?: string;
  topic?: string;
  subtopic?: string;
  source_ref?: JsonMap;
  payload?: JsonMap;
  occurred_at?: string;
};

export function recordRecallEventInBackground(
  authorization: string | null,
  event: RecallEvent,
  reason: string,
) {
  const work = recordRecallEvent(authorization, event).catch((error) => {
    console.error("praticase_recall_event_record_failed", reason, error);
  });
  const runtime = (globalThis as { EdgeRuntime?: EdgeRuntimeWithWaitUntil })
    .EdgeRuntime;
  if (runtime?.waitUntil) {
    runtime.waitUntil(work);
  }
}

async function recordRecallEvent(
  authorization: string | null,
  event: RecallEvent,
) {
  const token = authorization ?? "";
  if (!token.match(/^Bearer\s+\S+/i)) return;

  const baseUrl = (Deno.env.get("RECALL_BASE_URL") ||
    "https://recall.medasi.com.tr").trim();
  if (!baseUrl) return;

  const url = new URL("/recall/events", baseUrl);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4500);
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: token,
      },
      body: JSON.stringify(event),
      signal: controller.signal,
    });
    if (!response.ok) {
      console.error("praticase_recall_event_http_error", response.status);
    }
  } finally {
    clearTimeout(timeout);
  }
}
