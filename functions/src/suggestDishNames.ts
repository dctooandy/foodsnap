import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getClaudeClient, CLAUDE_HAIKU_MODEL, ANTHROPIC_API_KEY } from "./claudeClient";
import { checkAndIncrementQuota } from "./quota";
import type { SuggestDishNamesRequest, SuggestDishNamesResult } from "./types";

const RESULT_SCHEMA = {
  type: "object",
  properties: {
    candidates: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string", description: "A concise dish name." },
          description: {
            type: "string",
            description: "One short sentence describing the dish.",
          },
        },
        required: ["title", "description"],
        additionalProperties: false,
      },
    },
  },
  required: ["candidates"],
  additionalProperties: false,
};

export const suggestDishNames = onCall<SuggestDishNamesRequest>(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "請先登入。");
    }
    await checkAndIncrementQuota(request.auth.uid, request.auth.token.firebase?.sign_in_provider);

    const { items, targetLanguage } = request.data ?? {};

    if (!Array.isArray(items) || items.length === 0) {
      throw new HttpsError("invalid-argument", "items must be a non-empty array of { name, grams }.");
    }
    for (const item of items) {
      if (typeof item?.name !== "string" || !item.name.trim() || typeof item?.grams !== "number") {
        throw new HttpsError("invalid-argument", "Each item requires a non-empty name and numeric grams.");
      }
    }

    const lang = targetLanguage?.trim() || "Traditional Chinese (zh-TW)";
    const client = getClaudeClient();

    const ingredientList = items.map((i) => `- ${i.name}: ${i.grams}g`).join("\n");

    const response = await client.messages.create({
      model: CLAUDE_HAIKU_MODEL,
      max_tokens: 1024,
      output_config: { format: { type: "json_schema", schema: RESULT_SCHEMA } },
      messages: [
        {
          role: "user",
          content:
            `Given these ingredients (adjust quantities as needed):\n\n${ingredientList}\n\n` +
            `Suggest 3 to 5 distinct dish ideas that could primarily be made from them. ` +
            `Write each title and description in ${lang}. Keep descriptions to one short sentence.`,
        },
      ],
    });

    const textBlock = response.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new HttpsError("internal", "Model returned no text output.");
    }

    let result: SuggestDishNamesResult;
    try {
      result = JSON.parse(textBlock.text) as SuggestDishNamesResult;
    } catch {
      throw new HttpsError("internal", "Failed to parse model output as JSON.");
    }

    return result;
  }
);
