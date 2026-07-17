import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getClaudeClient, CLAUDE_MODEL, ANTHROPIC_API_KEY } from "./claudeClient";
import type { AnalyzeFoodRequest, AnalyzeFoodResult } from "./types";

const RESULT_SCHEMA = {
  type: "object",
  properties: {
    target_language: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name_original: {
            type: "string",
            description: "Name of the ingredient/food as it appears in the photo (original language).",
          },
          name_translated: {
            type: "string",
            description: "Name translated into the target language.",
          },
          estimated_grams: {
            type: "number",
            description: "Estimated weight of this item in grams, based on visual portion size.",
          },
          calories: {
            type: "number",
            description: "Estimated calories (kcal) for the estimated portion.",
          },
          confidence: {
            type: "string",
            enum: ["high", "medium", "low"],
            description: "Confidence in the identification and portion estimate.",
          },
        },
        required: ["name_original", "name_translated", "estimated_grams", "calories", "confidence"],
        additionalProperties: false,
      },
    },
    total_calories: {
      type: "number",
      description: "Sum of calories across all identified items.",
    },
  },
  required: ["target_language", "items", "total_calories"],
  additionalProperties: false,
};

const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // base64-decoded size guard

export const analyzeFood = onCall<AnalyzeFoodRequest>(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    const { imageBase64, mediaType, targetLanguage } = request.data ?? {};

    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError("invalid-argument", "imageBase64 is required.");
    }
    if (!mediaType || !["image/jpeg", "image/png", "image/webp"].includes(mediaType)) {
      throw new HttpsError("invalid-argument", "mediaType must be image/jpeg, image/png, or image/webp.");
    }
    // Rough size guard: base64 expands ~4/3 over raw bytes.
    if (imageBase64.length > (MAX_IMAGE_BYTES * 4) / 3) {
      throw new HttpsError("invalid-argument", "Image is too large (max 5MB).");
    }

    const lang = targetLanguage?.trim() || "Traditional Chinese (zh-TW)";
    const client = getClaudeClient();

    const response = await client.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      output_config: { format: { type: "json_schema", schema: RESULT_SCHEMA } },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: imageBase64 },
            },
            {
              type: "text",
              text:
                `Identify every distinct food ingredient or dish visible in this photo. ` +
                `For each item, translate its name into ${lang} (keep the original-language name too), ` +
                `estimate its portion size in grams from the visual, and estimate its calories (kcal) ` +
                `for that portion. Set target_language to "${lang}". If you cannot confidently see ` +
                `enough of an item to estimate portion size, still include it with confidence "low" ` +
                `and your best-guess grams rather than omitting it.`,
            },
          ],
        },
      ],
    });

    const textBlock = response.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new HttpsError("internal", "Model returned no text output.");
    }

    let result: AnalyzeFoodResult;
    try {
      result = JSON.parse(textBlock.text) as AnalyzeFoodResult;
    } catch {
      throw new HttpsError("internal", "Failed to parse model output as JSON.");
    }

    return result;
  }
);
