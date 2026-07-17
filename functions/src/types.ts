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
}

export interface RecipeResult {
  title: string;
  servings: number;
  ingredients: RecipeIngredient[];
  steps: string[];
  total_calories: number;
  notes: string;
}
