import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    chart: {
      ascendant: "Leo 12°",
      midheaven: "Taurus 02°",
      bodies: ["Sun 20° Aries", "Moon 18° Libra", "Mercury 02° Taurus"]
    },
    houseSystem: "Placidus",
    aspects: [
      { type: "trine", bodies: ["Sun", "Jupiter"], impact: "confidence + growth" },
      { type: "square", bodies: ["Moon", "Mars"], impact: "emotional reactivity" }
    ],
    transits: [
      { event: "Saturn return", window: "2026-03-01 to 2027-02-18", action: "build structures" }
    ]
  });
}

