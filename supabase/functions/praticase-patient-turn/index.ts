import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !supabaseAnonKey || !authorization) {
    return jsonResponse(
      { error: "Live Supabase configuration is missing" },
      500,
    );
  }

  const body = await request.json().catch(() => ({}));
  const sessionId = String(body.sessionId ?? body.session_id ?? "").trim();
  const message = String(body.message ?? "").trim();

  if (!sessionId || !message) {
    return jsonResponse({ error: "sessionId and message are required" }, 400);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data, error } = await supabase
    .schema("praticase")
    .rpc("record_patient_question", {
      p_session_id: sessionId,
      p_message: message,
    });

  if (error) {
    return jsonResponse({ error: error.message }, 400);
  }

  const result = Array.isArray(data) ? data[0] : data;
  return jsonResponse({
    patientMessageId: result?.patient_message_id ?? null,
    response: result?.response ?? "",
  });
});
