"use client";

import { useState } from "react";
import { Compass, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import clsx from "clsx";
import { useLanguage } from "@/contexts/LanguageContext";
import { useUsage } from "@/contexts/UsageContext";
import Image from "next/image";

export default function TarotPage() {
    const { t, locale } = useLanguage();
    const { incrementFeature } = useUsage();

    const spreads = [
        { id: "Three-Card", name: t.tarot.spreads.three, count: 3 },
        { id: "Celtic Cross", name: t.tarot.spreads.celtic, count: 10 },
        { id: "Decision", name: t.tarot.spreads.decision, count: 2 },
    ];

    const [question, setQuestion] = useState("");
    const [selectedSpread, setSelectedSpread] = useState(spreads[0]);
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState<any>(null);
    const [flippedCards, setFlippedCards] = useState<number[]>([]);

    // Update selected spread when component re-renders if the ID matches (to update label)
    const currentSpreadLabel = spreads.find(s => s.id === selectedSpread.id)?.name || selectedSpread.name;

    async function handleDraw() {
        if (!question) return;

        // Enforce Limit
        if (!incrementFeature()) return;

        setLoading(true);
        setResult(null);
        setFlippedCards([]);

        try {
            const res = await fetch("/api/tarot", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                // Pass locale to API
                body: JSON.stringify({ question, spreadType: selectedSpread.id, locale }),
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
        <div className="relative min-h-screen">
            {/* Background Image */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-5">
                <Image
                    src="/assets/Gemini_Generated_Image_d51vljd51vljd51v.png"
                    alt="Tarot Background"
                    fill
                    className="object-cover"
                />
            </div>

            <div className="relative z-10 max-w-5xl mx-auto space-y-12 py-8">
                <header className="space-y-4 text-center">
                    <h1 className="text-4xl font-bold flex items-center justify-center gap-3 text-charcoal">
                        <Compass className="text-aurum w-8 h-8" />
                        {t.tarot.title}
                    </h1>
                    <p className="text-charcoal/60 max-w-xl mx-auto">
                        {t.tarot.desc}
                    </p>
                </header>

                <div className="max-w-2xl mx-auto space-y-6">
                    <div className="space-y-2">
                        <label className="text-sm text-charcoal/70 font-medium">{t.tarot.questionLabel}</label>
                        <input
                            value={question}
                            onChange={(e) => setQuestion(e.target.value)}
                            placeholder={t.tarot.questionPlaceholder}
                            className="w-full bg-white/60 border border-white/50 rounded-xl px-4 py-3 focus:border-aurum/50 outline-none transition-colors text-charcoal placeholder-charcoal/40 shadow-sm font-medium"
                        />
                    </div>

                    <div className="space-y-2">
                        <label className="text-sm text-charcoal/70 font-medium">{t.tarot.selectSpread}</label>
                        <div className="flex flex-wrap gap-2">
                            {spreads.map((spread) => (
                                <button
                                    key={spread.id}
                                    onClick={() => setSelectedSpread(spread)}
                                    className={clsx(
                                        "px-4 py-2 rounded-full text-sm font-medium transition-all border shadow-sm",
                                        selectedSpread.id === spread.id
                                            ? "bg-gradient-to-r from-rose-gold to-aurum text-white border-transparent"
                                            : "bg-white/60 text-charcoal/70 border-white/50 hover:border-aurum/30 hover:bg-white/80"
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
                        className="w-full bg-gradient-to-r from-rose-gold to-aurum border border-white/20 text-white font-bold py-4 rounded-xl hover:shadow-soft-glow transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-md hover:scale-[1.01] active:scale-[0.99]"
                    >
                        {loading ? <Loader2 className="animate-spin text-white" /> : t.tarot.draw}
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
                                                        <Image
                                                            src={card.image}
                                                            alt={card.name}
                                                            fill
                                                            className="object-cover"
                                                        />
                                                    </div>
                                                    <div className="text-xs font-bold font-serif uppercase tracking-widest mt-auto">
                                                        {card.name}
                                                    </div>
                                                    {card.isReversed && <div className="text-[10px] text-red-600 font-bold uppercase">{t.tarot.reversed}</div>}
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
                                    className="max-w-3xl mx-auto bg-white/70 border border-white/60 rounded-2xl p-8 shadow-sm"
                                >
                                    <h3 className="text-xl font-semibold text-aurum mb-4">{t.tarot.interpretation}</h3>
                                    <div className="prose prose-p:text-charcoal/80 max-w-none whitespace-pre-line leading-relaxed">
                                        {result.interpretation}
                                    </div>
                                </motion.div>
                            )}
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>
        </div>
    );
}
