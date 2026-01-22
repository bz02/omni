"use client";

import { useState } from "react";
import { Compass, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import clsx from "clsx";

const spreads = [
    { id: "Three-Card", name: "Past / Present / Future", count: 3 },
    { id: "Celtic Cross", name: "Celtic Cross", count: 10 },
    { id: "Decision", name: "Either / Or Decision", count: 2 },
];

export default function TarotPage() {
    const [question, setQuestion] = useState("");
    const [selectedSpread, setSelectedSpread] = useState(spreads[0]);
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState<any>(null);
    const [flippedCards, setFlippedCards] = useState<number[]>([]);

    async function handleDraw() {
        if (!question) return;
        setLoading(true);
        setResult(null);
        setFlippedCards([]);

        try {
            const res = await fetch("/api/tarot", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ question, spreadType: selectedSpread.id }),
            });
            const json = await res.json();
            setResult(json);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    }

    const handleCardClick = (index: number) => {
        if (!flippedCards.includes(index)) {
            setFlippedCards(prev => [...prev, index]);
        }
    };

    return (
        <div className="max-w-5xl mx-auto space-y-12">
            <header className="space-y-4 text-center">
                <h1 className="text-4xl font-bold flex items-center justify-center gap-3">
                    <Compass className="text-aurum w-8 h-8" />
                    AI Immersive Tarot
                </h1>
                <p className="text-neutral-400 max-w-xl mx-auto">
                    Focus on your question. Let the Fisher-Yates algorithm shuffle the deck, and receive AI-synthesized guidance.
                </p>
            </header>

            <div className="max-w-2xl mx-auto space-y-6">
                <div className="space-y-2">
                    <label className="text-sm text-neutral-400">Your Question</label>
                    <input
                        value={question}
                        onChange={(e) => setQuestion(e.target.value)}
                        placeholder="What should I focus on this month?"
                        className="w-full bg-neutral-900 border border-neutral-800 rounded-xl px-4 py-3 focus:border-aurum/50 outline-none transition-colors"
                    />
                </div>

                <div className="space-y-2">
                    <label className="text-sm text-neutral-400">Select Spread</label>
                    <div className="flex flex-wrap gap-2">
                        {spreads.map((spread) => (
                            <button
                                key={spread.id}
                                onClick={() => setSelectedSpread(spread)}
                                className={clsx(
                                    "px-4 py-2 rounded-full text-sm font-medium transition-all border",
                                    selectedSpread.id === spread.id
                                        ? "bg-aurum text-black border-aurum"
                                        : "bg-neutral-900 text-neutral-400 border-neutral-800 hover:border-neutral-600"
                                )}
                            >
                                {spread.name}
                            </button>
                        ))}
                    </div>
                </div>

                <button
                    onClick={handleDraw}
                    disabled={!question || loading}
                    className="w-full bg-gradient-to-r from-nebula to-neutral-900 border border-aurum/30 text-aurum font-semibold py-4 rounded-xl hover:opacity-90 transition-all shadow-glow disabled:opacity-50 flex items-center justify-center gap-2"
                >
                    {loading ? <Loader2 className="animate-spin" /> : "Shuffle & Draw Cards"}
                </button>
            </div>

            {/* Card Display Area */}
            <AnimatePresence>
                {result && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="space-y-12"
                    >
                        <div className="flex flex-wrap justify-center gap-6 perspective-1000">
                            {result.cards.map((card: any, index: number) => {
                                const isFlipped = flippedCards.includes(index);
                                return (
                                    <div
                                        key={index}
                                        className="relative w-32 h-52 cursor-pointer group"
                                        onClick={() => handleCardClick(index)}
                                    >
                                        <motion.div
                                            className="w-full h-full relative preserve-3d transition-transform duration-700"
                                            animate={{ rotateY: isFlipped ? 180 : 0 }}
                                            transition={{ type: "spring", stiffness: 260, damping: 20 }}
                                            style={{ transformStyle: 'preserve-3d' }}
                                        >
                                            {/* Card Back */}
                                            <div className="absolute inset-0 backface-hidden bg-gradient-to-br from-neutral-800 to-neutral-950 border-2 border-neutral-700 rounded-xl flex items-center justify-center shadow-lg">
                                                <div className="w-24 h-44 border border-aurum/20 rounded opacity-30" />
                                            </div>

                                            {/* Card Front */}
                                            <div
                                                className="absolute inset-0 backface-hidden bg-starlight text-black rounded-xl shadow-glow overflow-hidden flex flex-col items-center p-2 text-center"
                                                style={{ transform: 'rotateY(180deg)' }}
                                            >
                                                <div className={clsx("w-full h-3/4 bg-neutral-200 mb-2 rounded overflow-hidden relative", card.isReversed && "rotate-180")}>
                                                    {/* Placeholder for card image */}
                                                    <div className="absolute inset-0 flex items-center justify-center text-xs text-neutral-500 font-serif opacity-20">
                                                        [Image]
                                                    </div>
                                                </div>
                                                <div className="text-xs font-bold font-serif uppercase tracking-widest mt-auto">
                                                    {card.name}
                                                </div>
                                                {card.isReversed && <div className="text-[10px] text-red-600 font-bold uppercase">Reversed</div>}
                                            </div>
                                        </motion.div>
                                    </div>
                                );
                            })}
                        </div>

                        {flippedCards.length === result.cards.length && (
                            <motion.div
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                className="max-w-3xl mx-auto bg-neutral-900/50 border border-neutral-800 rounded-2xl p-8"
                            >
                                <h3 className="text-xl font-semibold text-aurum mb-4">Oracle Interpretation</h3>
                                <div className="prose prose-invert max-w-none text-neutral-300 whitespace-pre-line leading-relaxed">
                                    {result.interpretation}
                                </div>
                            </motion.div>
                        )}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
