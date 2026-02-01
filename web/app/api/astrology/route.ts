import { NextResponse } from 'next/server';
import { ChatGoogleGenerativeAI } from "@langchain/google-genai";
import { HumanMessage, SystemMessage } from "@langchain/core/messages";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { date, time, place, locale } = body;
    const isZh = locale === 'zh';

    if (!process.env.GEMINI_API_KEY) {
      return NextResponse.json({
        content: isZh
          ? "错误：未配置 Gemini API Key。"
          : "Error: No Gemini API Key configured."
      }, { status: 500 });
    }

    const model = new ChatGoogleGenerativeAI({
      model: "gemini-3-pro-preview",
      temperature: 0.7,
      apiKey: process.env.GEMINI_API_KEY,
    });

    const systemPrompt = isZh
      ? `你是一位精通东西方玄学的算命大师。请根据用户的出生日期、时间和地点，为他们进行详细的命理分析。
         分析应包含：
         1. **西方占星**：太阳星座、上升星座、月亮星座及其影响。
         2. **中国五行八卦**：根据生辰八字推算的五行属性（金木水火土）及八卦意象。
         3. **综合运势与心理辅导**：结合两者提供深度的性格分析和心理建议。
         4. **行动指南**：基于命理的实用生活建议（如以此为基础的职业发展、人际关系等）。
         
         请使用Markdown格式输出，语气要专业、神秘但富有同理心。`
      : `You are a master of Eastern and Western metaphysics. Based on the user's birth date, time, and place, provide a detailed numerological and astrological analysis.
         The analysis should include:
         1. **Western Astrology**: Sun sign, Ascendant, Moon sign, and their influences.
         2. **Chinese Metaphysics**: Five Elements (Wu Xing) and Eight Trigrams (Ba Gua) based on the birth time.
         3. **Comprehensive Analysis & Counseling**: A deep dive into personality and psychological advice combining both systems.
         4. **Action Guide**: Practical life advice (career, relationships, etc.) based on these insights.
         
         Please output in Markdown format. The tone should be professional, mystical, yet empathetic.`;

    const userPrompt = `Birth Date: ${date}, Time: ${time}, Place: ${place}`;

    const response = await model.invoke([
      new SystemMessage(systemPrompt),
      new HumanMessage(userPrompt)
    ]);

    // Ensure content is a string
    const content = typeof response.content === 'string'
      ? response.content
      : Array.isArray(response.content)
        ? response.content.map(c => typeof c === 'string' ? c : '').join('')
        : String(response.content);

    return NextResponse.json({ content });

  } catch (e: any) {
    console.error("Astrology API Error:", e);
    return NextResponse.json({
      content: "The stars are clouded today. Please try again later. (Error: " + e.message + ")"
    }, { status: 500 });
  }
}

