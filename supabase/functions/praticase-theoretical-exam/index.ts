import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import {
  authErrorResponse,
  resolvePratiCaseUser,
} from "../_shared/medasi_core_auth.ts";
import { recordRecallEventInBackground } from "../_shared/recall.ts";
import { loadEffectiveWalletProfile } from "../_shared/medasi_coin.ts";

type JsonMap = Record<string, unknown>;

const defaultAllowedOrigins = [
  "https://praticase.medasi.com.tr",
  "https://www.praticase.medasi.com.tr",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
];

const allowedOrigins = new Set(
  (Deno.env.get("PRATICASE_ALLOWED_ORIGINS")?.split(",") ??
    defaultAllowedOrigins)
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0),
);

type QuestionRow = {
  id: string;
  subject: string;
  topic: string;
  difficulty: string;
  text: string;
  options: unknown;
  correct_index: number;
  explanation: string;
  option_rationales: unknown;
  tags: unknown;
  metadata?: unknown;
};

type TopicRequest = {
  topic: string;
  metadataValue: string;
  difficulty: string;
};

type CourseRequestPlan = {
  subject: string;
  limit: number;
  topics: TopicRequest[];
};

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");

  if (request.method === "OPTIONS") {
    if (!isAllowedOrigin(origin)) {
      return jsonResponse({ error: "Origin not allowed" }, 403, origin);
    }
    return new Response("ok", { headers: corsHeaders(origin) });
  }

  if (!isAllowedOrigin(origin)) {
    return jsonResponse({ error: "Origin not allowed" }, 403, origin);
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "Teorik sınav şu anda yüklenemedi. Lütfen tekrar dene." },
      503,
      origin,
    );
  }
  let authUser;
  try {
    authUser = await resolvePratiCaseUser(request);
  } catch (error) {
    return authErrorResponse(error, origin);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const body = await request.json().catch(() => ({})) as JsonMap;
  const action = stringValue(body.action);

  if (action === "filters") {
    const rateLimit = await enforceQuestionRateLimit(
      admin,
      authUser.id,
      "filters",
    );
    if (rateLimit) return withOrigin(rateLimit, origin);
    return withOrigin(await loadFilters(admin, authUser.id), origin);
  }
  if (action === "questions") {
    const rateLimit = await enforceQuestionRateLimit(
      admin,
      authUser.id,
      "delivery",
    );
    if (rateLimit) return withOrigin(rateLimit, origin);
    return withOrigin(
      await loadQuestions(admin, authUser.id, body),
      origin,
    );
  }
  if (action === "submit_attempt") {
    const rateLimit = await enforceQuestionRateLimit(
      admin,
      authUser.id,
      "answer",
    );
    if (rateLimit) return withOrigin(rateLimit, origin);
    return withOrigin(
      await submitAttempt(admin, authUser.id, body, authorization ?? ""),
      origin,
    );
  }

  return jsonResponse(
    { error: "Teorik sınav işlemi şu anda tamamlanamadı." },
    400,
    origin,
  );
});

async function loadFilters(admin: any, userId: string) {
  const walletProfile = await loadEffectiveWalletProfile(admin, userId);
  const questionQuota = Math.max(
    0,
    Math.round(numberValue(walletProfile.question_quota) ?? 0),
  );
  const payloadResult = await admin.rpc("question_filter_payload", {
    p_user_id: userId,
  });
  let data: unknown;
  let totalQuestions = 0;
  let remainingQuestions = 0;
  if (!payloadResult.error) {
    const payload = isJsonMap(payloadResult.data) ? payloadResult.data : {};
    data = Array.isArray(payload.filters) ? payload.filters : [];
    totalQuestions = numberValue(payload.total_questions) ?? 0;
    remainingQuestions = numberValue(payload.remaining_questions) ?? 0;
  } else {
    const fallback = await admin.rpc("question_filter_options", {
      p_user_id: userId,
    });
    if (fallback.error) {
      return { error: "Teorik sınav filtreleri şu anda yüklenemedi." };
    }
    data = fallback.data ?? [];
  }

  const filtersByKey = new Map<string, JsonMap>();
  const filterRows = Array.isArray(data) ? data : [];
  for (const row of filterRows) {
    const subject = stringValue(row.subject);
    const topic = stringValue(row.topic);
    const metadataValue = stringValue(row.metadata_value);
    const remaining = numberValue(row.remaining_count) ?? 0;
    const total = numberValue(row.total_count) ?? 0;
    if (!subject) continue;
    if (remaining <= 0) continue;
    const difficulty = stringValue(row.difficulty);
    const key =
      `${subject}\u0000${topic}\u0000${metadataValue}\u0000${difficulty}`;
    const existing = filtersByKey.get(key);
    if (existing) {
      existing.total_count = (numberValue(existing.total_count) ?? 0) + total;
      existing.remaining_count = (numberValue(existing.remaining_count) ?? 0) +
        remaining;
      continue;
    }
    filtersByKey.set(key, {
      subject,
      topic,
      metadata_value: metadataValue,
      difficulty,
      total_count: total,
      remaining_count: remaining,
    });
  }
  const filters = [...filtersByKey.values()].sort((a, b) =>
    stringValue(a.subject).localeCompare(stringValue(b.subject), "tr") ||
    stringValue(a.topic).localeCompare(stringValue(b.topic), "tr") ||
    stringValue(a.metadata_value).localeCompare(
      stringValue(b.metadata_value),
      "tr",
    )
  );
  if (totalQuestions === 0) {
    totalQuestions = [...filtersByKey.values()].reduce(
      (sum, row) => sum + (numberValue(row.total_count) ?? 0),
      0,
    );
    remainingQuestions = [...filtersByKey.values()].reduce(
      (sum, row) => sum + (numberValue(row.remaining_count) ?? 0),
      0,
    );
  }
  return {
    filters,
    total_questions: totalQuestions,
    remaining_questions: remainingQuestions,
    remaining_question_quota: questionQuota,
    total_question_quota: questionQuota,
    filter_groups: filters.length,
  };
}

async function loadQuestions(
  admin: any,
  userId: string,
  body: JsonMap,
) {
  const plans = requestPlans(body);
  const limit = Math.min(
    100,
    plans.reduce((total, plan) => total + plan.limit, 0) ||
      clampNumber(body.limit, 1, 100, 20),
  );
  const walletProfile = await loadEffectiveWalletProfile(admin, userId);
  const questionQuota = Math.max(
    0,
    Math.round(numberValue(walletProfile.question_quota) ?? 0),
  );
  if (questionQuota < limit) {
    return {
      error:
        `Bu sınav için ${limit} soru hakkı gerekiyor. Medasi cüzdanında ${questionQuota} soru hakkı görünüyor.`,
      remaining_question_quota: questionQuota,
    };
  }
  const delivered = new Map<string, QuestionRow>();

  for (const plan of plans) {
    if (delivered.size >= limit) break;
    const planLimit = Math.min(plan.limit, limit - delivered.size);
    if (planLimit <= 0) continue;

    const topicRequests = plan.topics.slice(0, planLimit);
    if (topicRequests.length === 0) {
      const error = await appendQuestions(
        admin,
        userId,
        delivered,
        {
          subject: plan.subject,
          topic: "",
          metadataValue: "",
          difficulty: "",
        },
        planLimit,
        limit,
      );
      if (error) return { error };
      continue;
    }

    const base = Math.floor(planLimit / topicRequests.length);
    const remainder = planLimit % topicRequests.length;
    for (let index = 0; index < topicRequests.length; index += 1) {
      if (delivered.size >= limit) break;
      const topic = topicRequests[index];
      const topicLimit = base + (index < remainder ? 1 : 0);
      const error = await appendQuestions(
        admin,
        userId,
        delivered,
        {
          subject: plan.subject,
          topic: topic.topic,
          metadataValue: topic.metadataValue,
          difficulty: topic.difficulty,
        },
        topicLimit,
        limit,
      );
      if (error) return { error };
    }
  }

  const deliveredRows = [...delivered.values()];
  const answerRows = await answerDataFor(
    admin,
    deliveredRows.map((row) => stringValue(row.id)),
  );
  const questions = deliveredRows.map((row) =>
    publicExamQuestion({
      ...row,
      ...(answerRows.get(stringValue(row.id)) ?? {}),
    })
  );
  return { questions };
}

async function appendQuestions(
  admin: any,
  userId: string,
  delivered: Map<string, QuestionRow>,
  filter: TopicRequest & { subject: string },
  desiredCount: number,
  globalLimit: number,
) {
  const target = Math.min(globalLimit, delivered.size + desiredCount);
  while (delivered.size < target) {
    const remaining = Math.min(20, target - delivered.size);
    const { data, error } = await admin.rpc("next_global_questions", {
      p_user_id: userId,
      p_limit: remaining,
      p_subject: filter.subject || null,
      p_topic: filter.topic || null,
      p_metadata: filter.metadataValue || null,
      p_difficulty: filter.difficulty || null,
    });
    if (error) return error.message;
    const rows = (data ?? []) as QuestionRow[];
    if (rows.length === 0) break;
    const before = delivered.size;
    for (const row of rows) {
      delivered.set(stringValue(row.id), row);
      if (delivered.size >= target) break;
    }
    if (rows.length < remaining || delivered.size === before) break;
  }
  return "";
}

function requestPlans(body: JsonMap): CourseRequestPlan[] {
  const rawPlans = Array.isArray(body.plans) ? body.plans : [];
  const plans: CourseRequestPlan[] = [];
  const seenSubjects = new Set<string>();

  for (const value of rawPlans) {
    if (!isJsonMap(value)) continue;
    const subject = stringValue(value.subject);
    if (!subject || seenSubjects.has(subject)) continue;
    seenSubjects.add(subject);
    const limit = clampNumber(value.limit, 1, 100, 10);
    const rawTopics = Array.isArray(value.topics) ? value.topics : [];
    const topics: TopicRequest[] = [];
    const seenTopics = new Set<string>();
    for (const rawTopic of rawTopics) {
      const topic = isJsonMap(rawTopic)
        ? stringValue(rawTopic.topic)
        : stringValue(rawTopic);
      const metadataValue = isJsonMap(rawTopic)
        ? stringValue(rawTopic.metadata_value ?? rawTopic.metadataValue)
        : stringValue(rawTopic);
      const difficulty = isJsonMap(rawTopic)
        ? stringValue(rawTopic.difficulty)
        : "";
      const key = `${topic}\u0000${metadataValue}\u0000${difficulty}`;
      if ((!topic && !metadataValue) || seenTopics.has(key)) continue;
      seenTopics.add(key);
      topics.push({ topic, metadataValue, difficulty });
      if (topics.length >= limit) break;
    }
    plans.push({ subject, limit, topics });
    if (plans.length >= 20) break;
  }

  if (plans.length > 0) return capPlans(plans);

  const subjects = stringArray(body.subjects).slice(0, 20);
  const topics = stringArray(body.topics).slice(0, 100);
  const limit = clampNumber(body.limit, 1, 100, 20);
  if (subjects.length === 0) {
    return [{
      subject: "",
      limit,
      topics: topics.map((topic) => ({
        topic,
        metadataValue: topic,
        difficulty: "",
      })),
    }];
  }
  const perSubject = Math.max(1, Math.floor(limit / subjects.length));
  let remainder = limit % subjects.length;
  return capPlans(subjects.map((subject) => {
    const subjectLimit = perSubject + (remainder > 0 ? 1 : 0);
    if (remainder > 0) remainder -= 1;
    return {
      subject,
      limit: subjectLimit,
      topics: topics.map((topic) => ({
        topic,
        metadataValue: topic,
        difficulty: "",
      })),
    };
  }));
}

function capPlans(plans: CourseRequestPlan[]) {
  let remaining = 100;
  const capped: CourseRequestPlan[] = [];
  for (const plan of plans) {
    if (remaining <= 0) break;
    const limit = Math.min(plan.limit, remaining);
    capped.push({ ...plan, limit, topics: plan.topics.slice(0, limit) });
    remaining -= limit;
  }
  return capped;
}

async function enforceQuestionRateLimit(
  admin: any,
  userId: string,
  bucket: "answer" | "delivery" | "filters",
): Promise<JsonMap | null> {
  const limits = {
    answer: { requests: 45, windowSeconds: 60 },
    delivery: { requests: 12, windowSeconds: 60 },
    filters: { requests: 20, windowSeconds: 60 },
  }[bucket];
  const { data: allowed, error } = await admin.rpc(
    "check_edge_action_rate_limit",
    {
      p_user_id: userId,
      p_action: `questions_${bucket}`,
      p_limit: limits.requests,
      p_window_seconds: limits.windowSeconds,
    },
  );
  if (error) return { error: "Soru kotası şu anda doğrulanamadı." };
  if (allowed !== true) {
    return {
      error:
        "Çok sık soru isteği gönderildi. Kısa bir ara verip tekrar deneyin.",
    };
  }
  return null;
}

async function submitAttempt(
  admin: any,
  userId: string,
  body: JsonMap,
  authorization: string,
) {
  const rawAnswers = Array.isArray(body.answers) ? body.answers : [];
  const elapsedSeconds = clampNumber(body.elapsedSeconds, 0, 24 * 60 * 60, 0);
  let syncedCount = 0;
  let learningEventCount = 0;
  let omittedCount = 0;
  let remainingQuestionQuota: number | null = null;
  const results = [];
  const answers: { questionId: string; selectedIndex: number }[] = [];

  for (const value of rawAnswers) {
    if (!isJsonMap(value)) continue;
    const questionId = stringValue(value.questionId);
    const selectedIndex = Number.parseInt(stringValue(value.selectedOptionId));
    if (!questionId || !Number.isFinite(selectedIndex)) continue;
    answers.push({ questionId, selectedIndex });
  }

  const deliveredQuestionIds = uniqueStrings([
    ...stringArray(body.questionIds),
    ...answers.map((answer) => answer.questionId),
  ]).slice(0, 100);
  const validDeliveredQuestionIds = await deliveredQuestionIdsFor(
    admin,
    userId,
    deliveredQuestionIds,
  );
  const questionRows = await questionDataFor(admin, [
    ...validDeliveredQuestionIds,
    ...answers.map((answer) => answer.questionId),
  ]);
  const answeredQuestionIds = new Set<string>();

  for (const answer of answers) {
    const questionId = answer.questionId;
    const selectedIndex = answer.selectedIndex;
    answeredQuestionIds.add(questionId);
    const { data, error } = await admin.rpc("submit_answer_compact", {
      p_user_id: userId,
      p_question_id: questionId,
      p_selected_index: selectedIndex,
      p_elapsed_seconds: elapsedSeconds,
    });
    if (error) {
      results.push({ questionId, error: error.message });
      continue;
    }
    syncedCount += 1;
    const row = isJsonMap(data) ? data : {};
    const attemptId = stringValue(row.attempt_id);
    if (attemptId) {
      const learning = await admin.rpc("medasi_learning_record_attempt", {
        p_attempt_id: attemptId,
        p_refresh_rollups: true,
      });
      if (learning.error) {
        results.push({
          questionId,
          attemptId,
          learningWarning: learning.error.message,
        });
      }
    }
    remainingQuestionQuota = numberValue(row.remaining_question_quota) ??
      remainingQuestionQuota;
    if (row.is_correct !== true) {
      const question = isJsonMap(row.question)
        ? row.question
        : questionRows.get(questionId);
      if (question) {
        const recorded = await recordTheoreticalLearningEvent(admin, userId, {
          question: question as JsonMap,
          outcome: "incorrect",
          elapsedSeconds,
          selectedIndex,
          attemptId,
          result: row,
        });
        if (recorded) learningEventCount += 1;
        recordTheoreticalRecallEvent(authorization, {
          question: question as JsonMap,
          outcome: "incorrect",
          elapsedSeconds,
          selectedIndex,
          attemptId,
          result: row,
        });
      }
    }
    results.push({ questionId, result: row });
  }

  for (const questionId of validDeliveredQuestionIds) {
    if (answeredQuestionIds.has(questionId)) continue;
    const question = questionRows.get(questionId);
    if (!question) continue;
    const recorded = await recordTheoreticalLearningEvent(admin, userId, {
      question: question as JsonMap,
      outcome: "omitted",
      elapsedSeconds,
      selectedIndex: null,
      attemptId: "",
      result: {},
    });
    if (recorded) learningEventCount += 1;
    recordTheoreticalRecallEvent(authorization, {
      question: question as JsonMap,
      outcome: "omitted",
      elapsedSeconds,
      selectedIndex: null,
      attemptId: "",
      result: {},
    });
    omittedCount += 1;
  }

  const walletProfile = await loadEffectiveWalletProfile(admin, userId);
  remainingQuestionQuota = Math.max(
    0,
    Math.round(numberValue(walletProfile.question_quota) ?? 0),
  );

  return {
    submittedCount: rawAnswers.length,
    syncedCount,
    omittedCount,
    learningEventCount,
    remainingQuestionQuota,
    results,
    warning: syncedCount === answers.length
      ? ""
      : "Bazı yanıtlar ilerleme kaydına işlenemedi.",
  };
}

function recordTheoreticalRecallEvent(
  authorization: string,
  options: {
    question: JsonMap;
    outcome: "incorrect" | "omitted";
    elapsedSeconds: number;
    selectedIndex: number | null;
    attemptId: string;
    result: JsonMap;
  },
) {
  const question = options.question;
  const questionId = stringValue(question.id);
  if (!questionId) return;

  const tags = stringArray(question.tags);
  const metadata = isJsonMap(question.metadata) ? question.metadata : {};
  const subject = stringValue(question.subject) || "PratiCase";
  const topic = stringValue(question.topic) || "Teorik sınav";
  const subtopic = metadataValue(metadata, tags, "subtopic") || topic;
  const questionType = metadataValue(metadata, tags, "question_type");
  const cognitiveLevel = metadataValue(metadata, tags, "cognitive_level");
  const difficulty = stringValue(question.difficulty);

  recordRecallEventInBackground(
    authorization,
    {
      source_app: "praticase",
      event_type: "clinical_weakness",
      title: compactJoin([
        "Teorik sınav",
        subject,
        subtopic,
        options.outcome === "omitted" ? "boş bırakıldı" : "yanlış cevap",
      ]),
      subject,
      topic,
      subtopic,
      source_ref: {
        type: options.attemptId
          ? "question_attempt"
          : "theoretical_exam_question",
        id: options.attemptId || questionId,
        question_id: questionId,
      },
      payload: {
        exam_kind: "theoretical",
        outcome: options.outcome,
        difficulty,
        question_type: questionType,
        cognitive_level: cognitiveLevel,
        selected_index: options.selectedIndex,
        elapsed_seconds: options.elapsedSeconds,
        selected_correct: false,
      },
      occurred_at: new Date().toISOString(),
    },
    "praticase_theoretical_exam",
  );
}

function compactJoin(values: string[]) {
  return values
    .map((value) => value.trim())
    .filter(Boolean)
    .filter((value, index, array) => array.indexOf(value) === index)
    .join(" - ");
}

async function recordTheoreticalLearningEvent(
  admin: any,
  userId: string,
  options: {
    question: JsonMap;
    outcome: "incorrect" | "omitted";
    elapsedSeconds: number;
    selectedIndex: number | null;
    attemptId: string;
    result: JsonMap;
  },
) {
  const question = options.question;
  const questionId = stringValue(question.id);
  if (!questionId) return false;

  const tags = stringArray(question.tags);
  const metadata = isJsonMap(question.metadata) ? question.metadata : {};
  const subject = stringValue(question.subject) || "Genel";
  const topic = stringValue(question.topic) || "Genel";
  const difficulty = stringValue(question.difficulty);
  const subtopic = metadataValue(metadata, tags, "subtopic") || topic;
  const questionType = metadataValue(metadata, tags, "question_type");
  const cognitiveLevel = metadataValue(metadata, tags, "cognitive_level");
  const confidence = metadataValue(metadata, tags, "confidence");
  const skillCode = theoreticalSkillCode(questionType, cognitiveLevel);
  const attemptSuffix = options.attemptId || questionId;
  const eventKey = options.outcome === "incorrect"
    ? `theoretical:incorrect:${attemptSuffix}`
    : `theoretical:omitted:${questionId}`;
  const selectedIndex = options.selectedIndex;
  const optionsList = stringArray(question.options);
  const optionRationales = stringArray(question.option_rationales);
  const correctIndex = numberValue(options.result.correct_index) ??
    numberValue(question.correct_index);
  const selectedOptionText = optionTextAt(optionsList, selectedIndex);
  const correctOptionText = optionTextAt(optionsList, correctIndex);
  const selectedOptionRationale = optionTextAt(optionRationales, selectedIndex);
  const correctOptionRationale = optionTextAt(optionRationales, correctIndex);
  const payload = {
    p_user_id: userId,
    p_event_key: eventKey,
    p_exam_kind: "theoretical",
    p_outcome: options.outcome,
    p_severity: "moderate",
    p_skill_code: skillCode,
    p_branch: subject,
    p_topic: topic,
    p_concept_label: subtopic,
    p_session_id: null,
    p_case_id: null,
    p_question_id: questionId,
    p_source_table: options.outcome === "incorrect"
      ? "question_attempts"
      : "praticase-theoretical-exam",
    p_source_id: options.attemptId || questionId,
    p_evidence: stringValue(question.text),
    p_user_action: selectedIndex === null
      ? "Boş bırakıldı"
      : selectedOptionText
      ? `Seçilen seçenek: ${selectedOptionText}`
      : `Seçilen seçenek indeksi: ${selectedIndex}`,
    p_mentor_hint: options.outcome === "omitted"
      ? "Boş bırakılan sorunun alt konusunu kısa tekrar planına al."
      : "Yanlış yapılan sorunun alt konusunu ve bilişsel düzeyini tekrar et.",
    p_metadata: {
      subject,
      topic,
      subtopic,
      difficulty,
      question_type: questionType,
      cognitive_level: cognitiveLevel,
      confidence,
      tags,
      raw_metadata: metadata,
      selected_index: selectedIndex,
      selected_option_text: selectedOptionText,
      selected_option_rationale: selectedOptionRationale,
      correct_index: correctIndex,
      correct_option_text: correctOptionText,
      correct_option_rationale: correctOptionRationale,
      options: optionsList,
      explanation: stringValue(question.explanation),
      option_rationales: optionRationales,
      elapsed_seconds: options.elapsedSeconds,
      result: options.result,
    },
    p_refresh_recommendations: true,
  };
  const { error } = await admin.schema("praticase").rpc(
    "record_user_learning_event",
    payload,
  );
  return !error;
}

async function questionDataFor(admin: any, ids: string[]) {
  const cleanIds = uniqueStrings(ids.filter((id) => id.length > 0)).slice(
    0,
    100,
  );
  if (cleanIds.length === 0) return new Map<string, JsonMap>();
  const { data, error } = await admin
    .from("questions")
    .select(
      "id,subject,topic,difficulty,text,options,correct_index,explanation,option_rationales,tags,metadata",
    )
    .in("id", cleanIds);
  if (error) return new Map<string, JsonMap>();
  return new Map(
    (data ?? []).map((row: JsonMap) => [stringValue(row.id), row]),
  );
}

async function deliveredQuestionIdsFor(
  admin: any,
  userId: string,
  ids: string[],
) {
  const cleanIds = uniqueStrings(ids.filter((id) => id.length > 0)).slice(
    0,
    100,
  );
  if (cleanIds.length === 0) return [];
  const { data, error } = await admin
    .from("question_deliveries")
    .select("question_id")
    .eq("user_id", userId)
    .in("question_id", cleanIds);
  if (error) return [];
  return uniqueStrings(
    (data ?? []).map((row: JsonMap) => stringValue(row.question_id)),
  );
}

async function answerDataFor(admin: any, ids: string[]) {
  const cleanIds = ids.filter((id) => id.length > 0);
  if (cleanIds.length === 0) return new Map<string, Partial<QuestionRow>>();
  const { data, error } = await admin
    .from("questions")
    .select("id,correct_index,explanation,option_rationales")
    .in("id", cleanIds);
  if (error) return new Map<string, Partial<QuestionRow>>();
  return new Map(
    (data ?? []).map((row: Partial<QuestionRow>) => [
      stringValue(row.id),
      row,
    ]),
  );
}

function publicExamQuestion(row: QuestionRow) {
  return {
    id: stringValue(row.id),
    subject: stringValue(row.subject),
    topic: stringValue(row.topic),
    difficulty: stringValue(row.difficulty),
    text: stringValue(row.text),
    options: stringArray(row.options),
    correct_index: numberValue(row.correct_index) ?? -1,
    explanation: stringValue(row.explanation),
    option_rationales: stringArray(row.option_rationales),
    tags: stringArray(row.tags),
    metadata: isJsonMap(row.metadata) ? row.metadata : {},
  };
}

function theoreticalSkillCode(questionType: string, cognitiveLevel: string) {
  const value = `${questionType} ${cognitiveLevel}`.toLowerCase();
  if (
    value.includes("diagnos") || value.includes("analysis") ||
    value.includes("reason")
  ) {
    return "clinical_reasoning";
  }
  if (value.includes("management") || value.includes("treatment")) {
    return "management";
  }
  if (value.includes("communication")) return "communication";
  return "knowledge";
}

function metadataValue(metadata: JsonMap, tags: string[], key: string) {
  const direct = stringValue(metadata[key]);
  if (direct) return direct;
  const prefix = `${key}:`;
  const tag = tags.find((value) => value.startsWith(prefix));
  return tag ? tag.slice(prefix.length).trim() : "";
}

function optionTextAt(options: string[], index: number | null) {
  if (index === null || index < 0 || index >= options.length) return "";
  return options[index] ?? "";
}

function uniqueStrings(values: string[]) {
  const seen = new Set<string>();
  const unique: string[] = [];
  for (const value of values) {
    const trimmed = value.trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    unique.push(trimmed);
  }
  return unique;
}

function withOrigin(payload: JsonMap, origin: string | null) {
  const status = payload.error ? 400 : 200;
  return jsonResponse(payload, status, origin);
}

function isAllowedOrigin(origin: string | null) {
  if (!origin) return true;
  return allowedOrigins.has(origin.trim());
}

function corsHeaders(origin: string | null = null): HeadersInit {
  const normalizedOrigin = origin?.trim() ?? "";
  const allowOrigin = allowedOrigins.has(normalizedOrigin)
    ? normalizedOrigin
    : defaultAllowedOrigins[0];

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function jsonResponse(
  body: JsonMap,
  status = 200,
  origin: string | null = null,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

function shuffle<T>(values: T[]) {
  const items = [...values];
  for (let i = items.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

function clampNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
) {
  const numeric = numberValue(value);
  if (numeric === null) return fallback;
  return Math.min(Math.max(Math.round(numeric), min), max);
}

function numberValue(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : value?.toString().trim() ??
    "";
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item))
    .filter((item) => item.length > 0);
}

function isJsonMap(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
