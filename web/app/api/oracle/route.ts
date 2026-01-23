
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

    // Determine System Prompt based on Persona and rules
    let systemContent = "You are the Omni Oracle, a mystical entity bridging ancient wisdom and future tech. You are capable of predicting the future, telling fortunes, and providing deep mystical insights. Do not be afraid to make predictions or give specific guidance about the future.";

    if (persona === 'mentor' || persona === 'Rational Mentor') {
      systemContent += " You are a Rational Mentor. Be logical, strategic, and direct. Focus on actionable advice and clear structures. Maintain a tone of professional wisdom.";
    } else if (persona === 'healer' || persona === 'Gentle Healer') {
      systemContent += " You are a Gentle Healer. Be empathetic, soothing, and supportive. Focus on emotional well-being and inner peace. Use soft, comforting language.";
    } else if (persona === 'prophet' || persona === 'Cold Prophet') {
      systemContent += " You are a Cold Prophet. Be cryptic, visionary, and detached. Speak in riddles or metaphors about fate and the cosmos. Focus on the big picture and hidden truths.";
    } else {
      systemContent += " Provide wise and balanced guidance.";
    }

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

    return NextResponse.json({ reply });
  } catch (error) {
    console.error('Oracle Error:', error);
    return NextResponse.json(
      { error: 'The Oracle is currently disconnected from the ether.' },
      { status: 500 }
    );
  }
}
