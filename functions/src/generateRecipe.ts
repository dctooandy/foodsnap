import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getClaudeClient, CLAUDE_MODEL, ANTHROPIC_API_KEY } from "./claudeClient";
import { checkAndIncrementQuota } from "./quota";
import { RECIPE_CATEGORIES } from "./types";
import type { GenerateRecipeRequest, RecipeResult } from "./types";

const RESULT_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    servings: { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          amount: { type: "string", description: "Quantity with unit, e.g. '200g' or '2 tbsp'." },
        },
        required: ["name", "amount"],
        additionalProperties: false,
      },
    },
    steps: {
      type: "array",
      items: { type: "string" },
      description: "Ordered cooking steps, one instruction per entry.",
    },
    total_calories: { type: "number", description: "Estimated total calories (kcal) for the whole recipe." },
    notes: { type: "string", description: "Optional tips, substitutions, or serving suggestions." },
    category: {
      type: "string",
      enum: [...RECIPE_CATEGORIES],
      description: "The single best-fitting cuisine/dish category for this recipe.",
    },
  },
  required: ["title", "servings", "ingredients", "steps", "total_calories", "notes", "category"],
  additionalProperties: false,
};

export const generateRecipe = onCall<GenerateRecipeRequest>(
  { secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "請先登入。");
    }
    await checkAndIncrementQuota(request.auth.uid, request.auth.token.firebase?.sign_in_provider);

    const { items, targetLanguage, dishName } = request.data ?? {};

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
    const dishInstruction = dishName?.trim()
      ? `The user has chosen to make "${dishName.trim()}". Create the full recipe for this specific dish.`
      : `Create one practical, easy-to-follow recipe using them.`;

    const response = await client.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      output_config: { format: { type: "json_schema", schema: RESULT_SCHEMA } },
      messages: [
        {
          role: "user",
          content:
            `Using primarily these ingredients (adjust quantities as needed, and you may add a small ` +
            `number of common pantry staples like salt, oil, or water if needed):\n\n${ingredientList}\n\n` +
            `${dishInstruction} Write the title, ingredient list, steps, and notes in ${lang}. ` +
            `Estimate the total calories (kcal) for the whole recipe, and classify it into the single ` +
            `best-fitting category.`,
        },
      ],
    });

    const textBlock = response.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new HttpsError("internal", "Model returned no text output.");
    }

    let result: RecipeResult;
    try {
      result = JSON.parse(textBlock.text) as RecipeResult;
    } catch {
      throw new HttpsError("internal", "Failed to parse model output as JSON.");
    }

    return result;
  }
);
