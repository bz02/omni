import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { answers, locale } = body;
    const isZh = locale === 'zh';

    const type = "INTJ";

    const facets = isZh ? {
      EI: { score: 75, label: "内向", facets: ["接收", "内敛", "亲密", "反思", "安静"], image: "/assets/mbti_intuition_1769151546183.png" },
      SN: { score: 60, label: "直觉", facets: ["抽象", "想象", "概念", "理论", "原创"], image: "/assets/mbti_intuition_1769151546183.png" },
      TF: { score: 85, label: "思考", facets: ["逻辑", "理性", "质疑", "批判", "坚强"], image: "/assets/mbti_thinking_1769151561204.png" },
      JP: { score: 55, label: "判断", facets: ["系统", "计划", "提前启动", "日程化", "条理"], image: "/assets/mbti_thinking_1769151561204.png" }
    } : {
      EI: { score: 75, label: "Introverted", facets: ["Receiving", "Contained", "Intimate", "Reflective", "Quiet"], image: "/assets/mbti_intuition_1769151546183.png" },
      SN: { score: 60, label: "Intuitive", facets: ["Abstract", "Imaginative", "Conceptual", "Theoretical", "Original"], image: "/assets/mbti_intuition_1769151546183.png" },
      TF: { score: 85, label: "Thinking", facets: ["Logical", "Reasonable", "Questioning", "Critical", "Tough"], image: "/assets/mbti_thinking_1769151561204.png" },
      JP: { score: 55, label: "Judging", facets: ["Systematic", "Planful", "Early-Starting", "Scheduled", "Methodical"], image: "/assets/mbti_thinking_1769151561204.png" }
    };

    const midZones = isZh
      ? ["你在'系统性 vs 随意性'维度上显示出中间区域偏好，表明你可以根据压力水平调整你的计划方式。"]
      : ["You show a mid-zone preference on the 'Systematic vs Casual' facet, suggesting you can adapt your planning style depending on stress levels."];

    // Simulate delay
    await new Promise(resolve => setTimeout(resolve, 1000));

    return NextResponse.json({
      type,
      facets,
      midZones,
      evolution: isZh ? "自上次评估以来，你的直觉分数提高了 5%。" : "Your Intuition score has increased by 5% since last assessment."
    });

  } catch (error) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}
