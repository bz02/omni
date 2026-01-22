import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { answers } = body;
    // answers is object like { q1: 'A', q2: 'B' ... }

    // Mock Scoring Logic
    // In reality this would calculate E/I, S/N, T/F, J/P scores based on weighted answers
    // Randomizing slightly for demo purposes

    const type = "INTJ";

    const facets = {
      EI: { score: 75, label: "Introverted", facets: ["Receiving", "Contained", "Intimate", "Reflective", "Quiet"] },
      SN: { score: 60, label: "Intuitive", facets: ["Abstract", "Imaginative", "Conceptual", "Theoretical", "Original"] },
      TF: { score: 85, label: "Thinking", facets: ["Logical", "Reasonable", "Questioning", "Critical", "Tough"] },
      JP: { score: 55, label: "Judging", facets: ["Systematic", "Planful", "Early-Starting", "Scheduled", "Methodical"] }
    };

    const midZones = [
      "You show a mid-zone preference on the 'Systematic vs Casual' facet, suggesting you can adapt your planning style depending on stress levels."
    ];

    // Simulate delay
    await new Promise(resolve => setTimeout(resolve, 1000));

    return NextResponse.json({
      type,
      facets,
      midZones,
      evolution: "Your Intuition score has increased by 5% since last assessment."
    });

  } catch (error) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}

