export const RECIPE_CATEGORIES = [
  "台式",
  "中式",
  "日式",
  "韓式",
  "西式",
  "東南亞",
  "甜點烘焙",
  "其他",
] as const;

export type RecipeCategory = (typeof RECIPE_CATEGORIES)[number];

export interface FoodItem {
  name_original: string;
  name_translated: string;
  estimated_grams: number;
  calories: number;
  confidence: "high" | "medium" | "low";
}

export interface AnalyzeFoodRequest {
  imageBase64: string;
  mediaType: "image/jpeg" | "image/png" | "image/webp";
  targetLanguage?: string;
}

export interface AnalyzeFoodResult {
  target_language: string;
  items: FoodItem[];
  total_calories: number;
}

export interface RecipeIngredient {
  name: string;
  amount: string;
}

export interface GenerateRecipeRequest {
  items: Array<{ name: string; grams: number }>;
  targetLanguage?: string;
  /** The dish the user picked from suggestDishNames, if any. */
  dishName?: string;
}

export interface RecipeResult {
  title: string;
  servings: number;
  ingredients: RecipeIngredient[];
  steps: string[];
  total_calories: number;
  notes: string;
  category: RecipeCategory;
}

export interface SuggestDishNamesRequest {
  items: Array<{ name: string; grams: number }>;
  targetLanguage?: string;
}

export interface DishNameCandidate {
  title: string;
  description: string;
}

export interface SuggestDishNamesResult {
  candidates: DishNameCandidate[];
}
