import Anthropic from "@anthropic-ai/sdk";
import { defineSecret } from "firebase-functions/params";

export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

let client: Anthropic | undefined;

export function getClaudeClient(): Anthropic {
  if (!client) {
    client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
  }
  return client;
}

export const CLAUDE_MODEL = "claude-opus-4-8";
