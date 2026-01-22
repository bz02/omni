import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  const body = await request.json();
  const { message, persona } = body;

  let responseText = "";

  if (persona === 'Rational Mentor') {
    responseText = "From a logical standpoint, your situation requires a systematic analysis of risks vs rewards. Focus on the data points you have, not just intuition.";
  } else if (persona === 'Gentle Healer') {
    responseText = "I sense a lot of heaviness in your heart. It's okay to take a step back and rest. Your feelings are valid, and healing is not linear.";
  } else {
    // Cold Prophet
    responseText = "The stars do not weep for you. The alignment suggests friction, and you must become harder than the obstacle if you wish to break it.";
  }

  // Simulate streaming or delay
  await new Promise(resolve => setTimeout(resolve, 1200));

  return NextResponse.json({
    reply: responseText,
    memoryId: "mem_" + Math.random().toString(36).substr(2, 9)
  });
}

