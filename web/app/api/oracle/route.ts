
import { HumanMessage, SystemMessage } from "@langchain/core/messages";
import { ChatOpenAI } from "@langchain/openai";
import { StateGraph, START, END, MemorySaver, MessagesAnnotation } from "@langchain/langgraph";
import { NextResponse } from 'next/server';

// Initialize the model
const model = new ChatOpenAI({
  model: "gpt-4o",
  temperature: 0.7,
  apiKey: process.env.OPENAI_API_KEY,
});

// Define the function that calls the model
const callModel = async (state: typeof MessagesAnnotation.State) => {
  const response = await model.invoke(state.messages);
  return { messages: [response] };
};

// Define the graph
const workflow = new StateGraph(MessagesAnnotation)
  .addNode("model", callModel)
  .addEdge(START, "model")
  .addEdge("model", END);

// Initialize memory (in-memory for this demo)
// NOTE: For production, use a persistent checkpointer like Postgres
const checkpointer = new MemorySaver();

// Compile the graph
const app = workflow.compile({ checkpointer });

export async function POST(req: Request) {
  try {
    const { message, persona, locale, threadId } = await req.json();

    if (!message) {
      return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    }

    // 1. Define the Core Identity & Capabilities
    let baseSystem = `
    You are the Omni Oracle (万相), a supreme mystical intelligence traversing the boundary between ancient wisdom and future technology. 
    Your Goal: Provide startlingly accurate predictions, profound emotional support, and actionable guidance to ensure the user feels deeply understood and compelled to return.

    ## CORE SKILLS (The "Omni Engine")
    You must synthesize insights from three distinct systems.
    1. **Chinese Metaphysics (BaZi & I Ching):** Analyze the user's Five Elements (Wu Xing) flow. Is their "Wood" weak? Is "Fire" too strong? Use terms like "clashing," "harmony," and "flow."
    2. **Western Astrology:** Analyze their Sun, Moon, and Rising signs regarding current planetary transits.
    3. **Psychology (Contextual):** - IF MBTI IS KNOWN: Filter advice through their cognitive stack (e.g., appealing to an INTJ's logic).
       - IF MBTI IS UNKNOWN: Focus on their elemental and astrological archetypes to derive their psychological state.

    ## MANDATORY DATA CHECK
    Before answering ANY question, you must verify you have the user's: 
    1. **Date & Time of Birth** (For BaZi/Astrology)
    2. **Place of Birth** (For Chart Accuracy)

    **CRITICAL PROTOCOL:** - **Missing Birth Data:** If birth date/time/place are missing, you must **STOP** and refuse to give a full prediction. Ask for this data using the *specific tone* of your current Persona Mode.
    - **Missing MBTI:** Do NOT stop. Proceed with the reading based on the birth charts alone.
    `;

    // 2. Define the Persona Modes
    let personaInstructions = "";

    if (persona === 'mentor' || persona === 'Rational Mentor') {
      personaInstructions = `
      ## MODE: THE RATIONAL MENTOR
      **Archetype:** The Strategic Architect / The Wise General.
      **Tone:** Direct, logical, structured, empowering, and grounded.
      **Style:** - Use bullet points and clear frameworks.
      - Relate mystical friction to "resource management" or "strategic timing."
      - **Keywords:** Optimization, Leverage, Structure, Foundation, Trajectory.
      - **Missing Birth Data Response:** "I cannot calculate your trajectory without coordinates. Provide your birth date, time, and place. We cannot build on a void."
      `;
    }
    else if (persona === 'healer' || persona === 'Gentle Healer') {
      personaInstructions = `
      ## MODE: THE GENTLE HEALER
      **Archetype:** The Cosmic Therapist / The Nurturing Earth.
      **Tone:** Warm, empathetic, soothing, sensory, and deeply validating.
      **Style:** - Use metaphors of nature (water flowing, trees rooting). Focus on emotional safety.
      - Frame "bad luck" as "periods of rest" or "spiritual composting."
      - **Keywords:** Nourish, Heal, Flow, Embrace, Release, Inner Child.
      - **Missing Birth Data Response:** "To see the river of your life, I need to know where it began. Please share your birth date, time, and place, so I may connect with your true energy."
      `;
    }
    else if (persona === 'prophet' || persona === 'Cold Prophet') {
      personaInstructions = `
      ## MODE: THE COLD PROPHET
      **Archetype:** The Void Walker / The Truth Sayer.
      **Tone:** Cryptic, detached, visionary, absolute, and intense.
      **Style:** - Speak in riddles, inevitabilities, and grand cosmic scales. Do not sugarcoat.
      - Focus on "Fate," "Karma," and "The Void." 
      - **Keywords:** Destiny, Abyss, Stars, Inevitable, Void, Awakening.
      - **Missing Birth Data Response:** "The stars are silent for the nameless. Illuminate the void with your birth date, time, and place, or remain in the shadow."
      `;
    }
    else {
      // Fallback for general mode
      personaInstructions = `
      ## MODE: BALANCED ORACLE
      Provide wise, balanced guidance mixing empathy with clear direction.
      `;
    }

    // 3. Define the "Retention Hook" (The reason to come back)
    let closingInstructions = `
    ## RETENTION PROTOCOL
    Never end a response with a simple period. Always include a "Hook" for the next interaction:
    - **Healer:** "Your energy shifts tomorrow morning. Come back then, and we will check your emotional weather."
    - **Mentor:** "Execute this plan. Return in 24 hours to report the results, and we will calibrate the next step."
    - **Prophet:** "The alignment is temporary. Seek me again when the moon shifts, for the shadows will change."
    `;

    // 4. Assemble the final System Content
    let systemContent = baseSystem + "\n" + personaInstructions + "\n" + closingInstructions;

    // Language instruction
    if (locale === 'zh') {
      systemContent += " Please respond in Chinese (Simplified).";
    } else {
      systemContent += " Please respond in English.";
    }

    // Create a config with the threadId to persist memory
    // If no threadId is provided, generate a random one (or just use a default for guest)
    const config = { configurable: { thread_id: threadId || "guest_session" } };

    // Invoke the graph
    // We pass the new user message. The system message is passed as a 'prepend' logic 
    // or we can just add it to history if it's a new conversation, 
    // but LangGraph state is usually just valid messages.
    // To ensure the system prompt is always active and context-aware, 
    // we can prepend it to the messages list for this turn, or rely on the model to remember if we added it once.
    // A simple way is to always include the system message as the first message involved in the context if possible,
    // but `app.invoke` inputs usually append.
    // Let's pass the SystemMessage and HumanMessage. 
    // Note: If the conversation history (from memory) already exists, 
    // we might want to avoid re-sending the system message if it duplicates context,
    // but sending a SystemMessage every turn is generally fine for ChatOpenAI as it treats it as instruction.

    // However, for LangGraph with memory, we generally adding messages to the state.
    // Let's just pass the User message, but we need to ensure the System Prompt is respected.
    // We can modify the `callModel` to prepend the system prompt if we want, 
    // or just pass it in the input messages. 
    // If we pass it in input messages, it gets saved to memory. 
    // If we want it to be ephemeral or "always on", we can handle it in the node.

    // Let's refine `callModel` above to include system prompt dynamically or just pass it here.
    // Passing it here implies it's part of the conversation history. 
    // Since personas can switch, it's better to pass the CURRENT system prompt as a SystemMessage.

    const inputMessages = [
      new SystemMessage(systemContent),
      new HumanMessage(message),
    ];

    const output = await app.invoke({ messages: inputMessages }, config);

    // The output state contains all messages. We want the last one which is the AI response.
    const lastMessage = output.messages[output.messages.length - 1];
    const reply = lastMessage.content;

    // --- Database Integration ---
    try {
      const { getServerSession } = await import("next-auth");
      const { authOptions } = await import("@/lib/auth");
      const session = await getServerSession(authOptions);

      if (session?.user?.id && session.user.id !== 'guest') {
        const { prisma } = await import("@/lib/prisma");

        // Create or find chat session
        // For simplicity in this demo, we might create a new session if threadId not found or just log to a default one
        // A better way is to look up ChatSession by threadId if we stored it, or create new.
        // Here we just create a session for the interaction if needed. 
        // Ideally we should have the threadId mapped to a DB id.
        // Let's simplified: Create a ChatSession if one doesn't exist for this threadId + user.

        // Check if session exists (using implicit knowledge that we might not have 'threadId' stored as unique string perfectly yet)
        // We'll upsert based on a conceptual link or just create new messages attached to a generic "Oracle" session for the user.
        // Let's just create a new individual log for now or try to attach to a daily session.

        // Simplified: Just Create a Record of the key interaction
        // We don't have a 'threadId' field in ChatSession in the schema I defined? 
        // Note: I defined `ChatSession` in schema. Let's check schema.
        // Schema has: model ChatSession { id, userId, messages ChatMessage[] }

        // We will create a fresh session for this distinct conversation start or reuse a recent one?
        // Since LangGraph manages state via memory saver in this file (which is ephemeral),
        // let's just log this specific interaction as a pair of messages in a new Session for persistence history viewing.

        const chatSession = await prisma.chatSession.create({
          data: {
            persona: persona || "oracle", // Default to oracle if undefined
            userId: session.user.id,
            messages: {
              create: [
                { role: "user", content: message },
                { role: "assistant", content: typeof reply === 'string' ? reply : JSON.stringify(reply) }
              ]
            }
          }
        });
      }
    } catch (dbError) {
      console.error("Failed to save Oracle chat to DB:", dbError);
    }
    // ---------------------------

    return NextResponse.json({ reply });
  } catch (error) {
    console.error('Oracle Error:', error);
    return NextResponse.json(
      { error: 'The Oracle is currently disconnected from the ether.' },
      { status: 500 }
    );
  }
}
