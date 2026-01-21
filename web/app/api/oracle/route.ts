import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({
    persona: "Rational Mentor",
    reply: "Ground your plans in clear milestones. Saturn return invites durable systems; pair daily tarot draws with weekly retros.",
    memoryHint: "Last session: career pivot discussion on 2025-12-14."
  });
}

