import { NextResponse } from 'next/server';

const majorArcana = [
  "The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
  "The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit",
  "Wheel of Fortune", "Justice", "The Hanged Man", "Death", "Temperance",
  "The Devil", "The Tower", "The Star", "The Moon", "The Sun",
  "Judgement", "The World"
];

const suits = ["Wands", "Cups", "Swords", "Pentacles"];

// Generate full deck
const fullDeck = [
  ...majorArcana.map(name => ({ name, type: 'Major' })),
  ...suits.flatMap(suit =>
    ["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Page", "Knight", "Queen", "King"]
      .map(val => ({ name: `${val} of ${suit}`, type: 'Minor' }))
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
    const { question, spreadType } = body;

    const shuffled = shuffleDeck(fullDeck);

    // Draw based on spread
    let drawCount = 3;
    if (spreadType === 'Celtic Cross') drawCount = 10;
    else if (spreadType === 'Decision') drawCount = 2;

    const drawnCards = shuffled.slice(0, drawCount).map(card => ({
      ...card,
      isReversed: Math.random() > 0.8, // 20% chance of reversal
    }));

    // Mock AI interpretation
    const interpretation = `You asked: "${question}". 
    
    The cards suggest a powerful transition. ${drawnCards[0].name} ${drawnCards[0].isReversed ? '(Reversed)' : ''} in the first position indicates that your current foundation is shifting.
    
    With ${drawnCards[1].name} appearing, you are being called to examine your inner motivations.
    
    The outcome looks promising if you embrace the energy of ${drawnCards[drawnCards.length - 1].name}.`;

    // Simulate thinking delay
    await new Promise(resolve => setTimeout(resolve, 1500));

    return NextResponse.json({
      cards: drawnCards,
      interpretation
    });

  } catch (error) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}

