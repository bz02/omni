import { NextResponse } from "next/server";

type Card = { name: string; orientation: "upright" | "reversed"; meaning: string };

function fisherYatesShuffle<T>(array: T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

const deck: Card[] = [
  { name: "The Fool", orientation: "upright", meaning: "new journey" },
  { name: "The Magician", orientation: "upright", meaning: "manifestation" },
  { name: "The Star", orientation: "upright", meaning: "renewal" },
  { name: "The Moon", orientation: "reversed", meaning: "illusions lifted" }
];

export async function POST() {
  const shuffled = fisherYatesShuffle(deck).slice(0, 3);
  return NextResponse.json({
    spread: "Past-Present-Future",
    cards: shuffled,
    aiSummary: "Context-aware interpretation combining tarot and natal profile."
  });
}

