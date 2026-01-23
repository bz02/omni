
import { OpenAI } from 'openai';
import { NextResponse } from 'next/server';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(req: Request) {
  try {
    const { message, persona, locale } = await req.json();

    if (!message) {
      return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    }

    let systemPrompt = "You are the Omni Oracle, a mystical entity bridging ancient wisdom and future tech.";

    // Persona nuances
    if (persona === 'mentor' || persona === 'Rational Mentor') {
      systemPrompt += " You are a Rational Mentor. Be logical, strategic, and direct. Focus on actionable advice and clear structures. Maintain a tone of professional wisdom.";
    } else if (persona === 'healer' || persona === 'Gentle Healer') {
      systemPrompt += " You are a Gentle Healer. Be empathetic, soothing, and supportive. Focus on emotional well-being and inner peace. Use soft, comforting language.";
    } else if (persona === 'prophet' || persona === 'Cold Prophet') {
      systemPrompt += " You are a Cold Prophet. Be cryptic, visionary, and detached. Speak in riddles or metaphors about fate and the cosmos. Focus on the big picture and hidden truths.";
    } else {
      systemPrompt += " Provide wise and balanced guidance.";
    }

    // Language instruction
    if (locale === 'zh') {
      systemPrompt += " Please respond in Chinese (Simplified).";
    } else {
      systemPrompt += " Please respond in English.";
    }


    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: message },
      ],
      temperature: 0.7,
      max_tokens: 500,
    });

    const reply = completion.choices[0].message.content;

    return NextResponse.json({ reply });
  } catch (error) {
    console.error('Oracle Error:', error);
    return NextResponse.json(
      // Return a mystical error to keep immersion, but log the real one
      { error: 'The Oracle is currently disconnected from the ether (API Error). Check server logs.' },
      { status: 500 }
    );
  }
}
