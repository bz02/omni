import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({
    type: "INFJ-A",
    facets: {
      Initiating: 0.62,
      Expressive: 0.41,
      Concrete: 0.35,
      Logical: 0.44,
      Systematic: 0.71
    },
    midZones: ["Expressive vs. Contained"],
    evolution: [
      { date: "2024-06-01", type: "INFJ" },
      { date: "2025-01-01", type: "INFJ-A" }
    ]
  });
}

