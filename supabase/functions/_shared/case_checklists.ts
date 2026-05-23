type JsonMap = Record<string, unknown>;

type ChecklistFetch = {
  data: GeneratedChecklistRow[] | null;
  error?: { message?: string };
};

type GeneratedChecklistRow = {
  id?: string;
  course?: string;
  case_name?: string;
  difficulty?: string;
  diagnosis_name?: string;
  content_type?: string;
  payload?: JsonMap;
  ai_provider?: string;
  ai_model?: string;
  source_format_file?: string;
  generated_at?: string;
};

export type CaseChecklistContext = {
  history: GeneratedChecklistRow[];
  physicalExam: GeneratedChecklistRow[];
  laboratory: GeneratedChecklistRow[];
  imaging: GeneratedChecklistRow[];
  diagnostic: GeneratedChecklistRow[];
};

export async function loadCaseChecklists(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  caseId: string,
): Promise<CaseChecklistContext> {
  const [history, physicalExam, laboratory, imaging, diagnostic] = await Promise
    .all([
      latestChecklistRows(supabase, "praticase_history_checklists", caseId),
      latestChecklistRows(
        supabase,
        "praticase_physical_exam_checklists",
        caseId,
      ),
      latestChecklistRows(supabase, "praticase_laboratory_checklists", caseId),
      latestChecklistRows(supabase, "praticase_imaging_checklists", caseId),
      latestChecklistRows(supabase, "praticase_diagnostic_checklists", caseId),
    ]);

  return {
    history,
    physicalExam,
    laboratory,
    imaging,
    diagnostic,
  };
}

export function mergeCaseChecklistContext(
  caseData: JsonMap,
  checklists: CaseChecklistContext,
): JsonMap {
  const historyItems = payloadItems(checklists.history, [
    "historyItems",
    "redFlags",
    "negativeFindings",
  ]);
  const physicalItems = payloadItems(checklists.physicalExam, [
    "physicalExamItems",
    "criticalFindings",
    "negativeFindings",
  ]);
  const laboratoryItems = payloadItems(checklists.laboratory, [
    "laboratoryItems",
    "bedsideTests",
    "microbiologyPathologyTests",
  ]);
  const imagingItems = payloadItems(checklists.imaging, [
    "imagingItems",
    "negativeOrNormalImagingFindings",
    "redFlagImaging",
  ]);
  const diagnosticItems = payloadItems(checklists.diagnostic, [
    "primaryDiagnosis",
    "differentialDiagnoses",
    "mustNotMissDiagnoses",
    "exclusionDiagnoses",
  ]);
  const unnecessaryTests = [
    ...payloadItems(checklists.laboratory, ["unnecessaryOrHarmfulTests"]),
    ...payloadItems(checklists.imaging, ["unnecessaryImaging"]),
  ];

  return {
    ...caseData,
    expected_history: fallbackArray(historyItems, caseData.expected_history),
    expected_physical_exam: fallbackArray(
      physicalItems,
      caseData.expected_physical_exam,
    ),
    expected_differentials: fallbackArray(
      diagnosticItems,
      caseData.expected_differentials,
    ),
    expected_tests: fallbackArray(
      [...laboratoryItems, ...imagingItems],
      caseData.expected_tests,
    ),
    unnecessary_tests: fallbackArray(
      unnecessaryTests,
      caseData.unnecessary_tests,
    ),
    admin_generated_checklists: checklists,
  };
}

async function latestChecklistRows(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  table: string,
  caseId: string,
): Promise<GeneratedChecklistRow[]> {
  const result = await supabase
    .schema("praticase")
    .from(table)
    .select(
      "id,course,case_name,difficulty,diagnosis_name,content_type,payload,ai_provider,ai_model,source_format_file,generated_at",
    )
    .eq("case_id", caseId)
    .order("generated_at", { ascending: false })
    .limit(1) as ChecklistFetch;

  if (result.error) return [];
  return result.data ?? [];
}

function payloadItems(
  rows: GeneratedChecklistRow[],
  keys: string[],
): unknown[] {
  const items: unknown[] = [];
  for (const row of rows) {
    const payload = row.payload ?? {};
    for (const key of keys) {
      const value = payload[key];
      if (Array.isArray(value)) {
        items.push(...value);
      } else if (value && typeof value === "object") {
        items.push(value);
      }
    }
  }
  return items;
}

function fallbackArray(primary: unknown[], fallback: unknown): unknown[] {
  if (primary.length > 0) return primary;
  return Array.isArray(fallback) ? fallback : [];
}
