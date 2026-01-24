import { NextResponse } from 'next/server';

const majorArcana = [
  "The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
  "The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit",
  "Wheel of Fortune", "Justice", "The Hanged Man", "Death", "Temperance",
  "The Devil", "The Tower", "The Star", "The Moon", "The Sun",
  "Judgement", "The World"
];

const majorArcanaZh = [
  "愚人", "魔术师", "女祭司", "皇后", "皇帝",
  "教皇", "恋人", "战车", "力量", "隐士",
  "命运之轮", "正义", "倒吊人", "死神", "节制",
  "恶魔", "高塔", "星星", "月亮", "太阳",
  "审判", "世界"
];

const suits = ["Wands", "Cups", "Swords", "Pentacles"];
const suitsZh = ["权杖", "圣杯", "宝剑", "星币"];

const values = ["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Page", "Knight", "Queen", "King"];
const valuesZh = ["首牌", "2", "3", "4", "5", "6", "7", "8", "9", "10", "侍从", "骑士", "王后", "国王"];

// Generate full decks
const generateDeck = (majors: string[], suitNames: string[], vals: string[]) => [
  ...majors.map(name => ({ name, type: 'Major' })),
  ...suitNames.flatMap(suit =>
    vals.map(val => ({ name: `${suit}${val}`, type: 'Minor' })) // Chinese style usually Suit+Value e.g. 权杖5
  )
];

const deckEn = [
  ...majorArcana.map(name => ({ name, type: 'Major' })),
  ...suits.flatMap(suit =>
    values.map(val => ({ name: `${val} of ${suit}`, type: 'Minor' }))
  )
];

// For Chinese deck construction
const deckZh = [
  ...majorArcanaZh.map(name => ({ name, type: 'Major' })),
  ...suitsZh.flatMap(suit =>
    valuesZh.map(val => ({ name: `${suit}${val}`, type: 'Minor' }))
  )
];


// Fisher-Yates Shuffle
function shuffleDeck(deck: any[]) {
  const newDeck = [...deck];
  for (let i = newDeck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [newDeck[i], newDeck[j]] = [newDeck[j], newDeck[i]];
  }
  return newDeck;
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { question, spreadType, locale } = body;
    const isZh = locale === 'zh';

    const fullDeck = isZh ? deckZh : deckEn;
    const shuffled = shuffleDeck(fullDeck);

    // Draw based on spread
    let drawCount = 3;
    if (spreadType === 'Celtic Cross') drawCount = 10;
    else if (spreadType === 'Decision') drawCount = 2;

    // Available images (using the ones we identified)
    const cardImages = [
      "/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png",
      "/assets/Gemini_Generated_Image_5lv2xh5lv2xh5lv2.png",
      "/assets/Gemini_Generated_Image_ae247sae247sae24.png",
      "/assets/Gemini_Generated_Image_d51vljd51vljd51v.png"
    ];

    const drawnCards = shuffled.slice(0, drawCount).map((card, index) => ({
      ...card,
      isReversed: Math.random() > 0.8, // 20% chance of reversal
      image: cardImages[index % cardImages.length] // Cycle through available images
    }));

    // Mock AI interpretation
    const interpretation = isZh
      ? `您问了: "${question}"。
    
    牌面预示着强烈的转变。第一张牌 ${drawnCards[0].name} ${drawnCards[0].isReversed ? '(逆位)' : ''} 表明您当下的基础正在动摇。
    
    随着 ${drawnCards[1].name} 的出现，宇宙召唤您去审视内心的动机。
    
    如果您能拥抱 ${drawnCards[drawnCards.length - 1].name} 的能量，结果将是非常积极的。`
      : `You asked: "${question}". 
    
    The cards suggest a powerful transition. ${drawnCards[0].name} ${drawnCards[0].isReversed ? '(Reversed)' : ''} in the first position indicates that your current foundation is shifting.
    
    With ${drawnCards[1].name} appearing, you are being called to examine your inner motivations.
    
    The outcome looks promising if you embrace the energy of ${drawnCards[drawnCards.length - 1].name}.`;

    // Simulate thinking delay
    await new Promise(resolve => setTimeout(resolve, 1500));

    // --- Database Integration ---
    try {
      const { getServerSession } = await import("next-auth");
      const { authOptions } = await import("../auth/[...nextauth]/route");
      const session = await getServerSession(authOptions);

      if (session?.user?.id) {
        const { prisma } = await import("@/lib/prisma"); // Dynamic import to avoid circular dep issues if any
        await prisma.reading.create({
          data: {
            type: "TAROT",
            data: { cards: drawnCards, spreadType, question },
            result: interpretation,
            userId: session.user.id
          }
        });
      }
    } catch (dbError) {
      console.error("Failed to save reading to DB:", dbError);
      // We don't fail the request if DB fails, just log it
    }
    // ---------------------------

    return NextResponse.json({
      cards: drawnCards,
      interpretation
    });

  } catch (error) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}
