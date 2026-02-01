"use client";

import { useState } from "react";
import { Brain, ArrowRight, Loader2 } from "lucide-react";
import { motion } from "framer-motion";
import { useLanguage } from "@/contexts/LanguageContext";
import { useUsage } from "@/contexts/UsageContext";
import Image from "next/image";



export default function MBTIPage() {
    const { t, locale } = useLanguage();
    const { incrementFeature } = useUsage();
    const questions = t.mbti.questions;
    const [started, setStarted] = useState(false);
    const [currentQ, setCurrentQ] = useState(0);
    const [answers, setAnswers] = useState<any>({});
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState<any>(null);

    const handleAnswer = (optionIdx: number) => {
        setAnswers({ ...answers, [questions[currentQ].id]: optionIdx });
        if (currentQ < questions.length - 1) {
            setCurrentQ(prev => prev + 1);
        } else {
            submitAnswers();
        }
    };

    async function submitAnswers() {
        setLoading(true);
        try {
            const res = await fetch("/api/mbti", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ answers, locale }),
            });
            const json = await res.json();
            setResult(json);
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    }

    if (result) {
        return (
            <div className="relative min-h-screen">
                {/* Background Image */}
                <div className="fixed inset-0 z-0 pointer-events-none opacity-10 mix-blend-multiply">
                    <Image
                        src="/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png"
                        alt="MBTI Background"
                        fill
                        className="object-cover"
                    />
                </div>

                <div className="relative z-10 max-w-4xl mx-auto space-y-12 py-8">
                    <header className="text-center space-y-4">
                        <h1 className="text-4xl font-bold text-charcoal">{t.mbti.profile}: {result.type}</h1>
                        <p className="text-charcoal/60 font-medium">{t.mbti.title}</p>
                    </header>

                    <div className="grid md:grid-cols-2 gap-8">
                        {Object.entries(result.facets).map(([key, val]: [string, any]) => (
                            <div key={key} className="bg-white/70 border border-white/60 p-6 rounded-2xl relative overflow-hidden group shadow-sm hover:shadow-md transition-all">
                                <div className="absolute top-0 right-0 w-32 h-32 opacity-20 group-hover:opacity-30 transition-opacity mix-blend-multiply">
                                    <Image src={val.image} alt={val.label} fill className="object-cover" />
                                </div>
                                <div className="flex justify-between items-center mb-4 relative z-10">
                                    <span className="text-xl font-bold text-charcoal">{key}</span>
                                    <span className="text-aurum font-bold">{val.label} ({val.score}%)</span>
                                </div>
                                <div className="w-full bg-charcoal/10 h-2 rounded-full overflow-hidden mb-4 relative z-10">
                                    <div className="bg-gradient-to-r from-rose-gold to-aurum h-full transition-all duration-1000" style={{ width: `${val.score}%` }} />
                                </div>
                                <div className="flex flex-wrap gap-2 relative z-10">
                                    {val.facets.map((f: string) => (
                                        <span key={f} className="text-xs bg-white/80 border border-rose-gold/20 px-2 py-1 rounded text-charcoal/70 font-medium">{f}</span>
                                    ))}
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className="bg-gradient-to-tr from-white/60 to-rose-gold/10 border border-white/50 p-6 rounded-2xl shadow-sm">
                        <h3 className="text-lg font-bold text-charcoal mb-2">{t.mbti.midZone}</h3>
                        <ul className="list-disc list-inside space-y-2 text-charcoal/80">
                            {result.midZones.map((z: string, i: number) => <li key={i}>{z}</li>)}
                        </ul>
                    </div>

                    <div className="text-center text-sm text-charcoal/50 font-medium">
                        {result.evolution}
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="relative min-h-screen flex flex-col">
            {/* Background Image */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-5">
                <Image
                    src="/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png"
                    alt="MBTI Background"
                    fill
                    className="object-cover"
                />
            </div>

            <div className="relative z-10 max-w-3xl mx-auto min-h-[60vh] flex flex-col items-center justify-center flex-1 p-6">
                <div className="bg-white/80 backdrop-blur-xl p-8 rounded-[2rem] shadow-xl border border-white/50 w-full">
                    {!started ? (
                        <div className="text-center space-y-6">
                            <Brain className="w-16 h-16 text-aurum mx-auto" />
                            <h1 className="text-4xl font-bold text-charcoal font-display">{t.mbti.title}</h1>
                            <p className="text-charcoal/80 max-w-lg mx-auto font-medium leading-relaxed">
                                {t.mbti.desc}
                            </p>
                            <button
                                onClick={() => {
                                    if (incrementFeature()) {
                                        setStarted(true);
                                    }
                                }}
                                className="px-8 py-3 bg-gradient-to-r from-rose-gold to-aurum text-white font-semibold rounded-full hover:opacity-90 transition-all text-lg shadow-soft-glow"
                            >
                                {t.mbti.start}
                            </button>
                        </div>
                    ) : loading ? (
                        <div className="flex flex-col items-center gap-4 py-12">
                            <Loader2 className="w-12 h-12 animate-spin text-aurum" />
                            <p className="text-charcoal/70 font-medium">{t.mbti.analyzing}</p>
                        </div>
                    ) : (
                        <motion.div
                            key={currentQ}
                            initial={{ opacity: 0, x: 20 }}
                            animate={{ opacity: 1, x: 0 }}
                            className="space-y-8"
                        >
                            <div className="flex justify-between text-sm text-charcoal/60 font-bold uppercase tracking-wider">
                                <span>{t.mbti.question} {currentQ + 1} / {questions.length}</span>
                                <span>{Math.round(((currentQ) / questions.length) * 100)}% {t.mbti.complete}</span>
                            </div>

                            <div className="h-2 bg-neutral-100 rounded-full overflow-hidden">
                                <div
                                    className="h-full bg-aurum transition-all duration-300"
                                    style={{ width: `${((currentQ) / questions.length) * 100}%` }}
                                />
                            </div>

                            <h2 className="text-2xl font-bold text-center text-charcoal py-4">{questions[currentQ].text}</h2>

                            <div className="space-y-3">
                                {questions[currentQ].options.map((opt, idx) => (
                                    <button
                                        key={idx}
                                        onClick={() => handleAnswer(idx)}
                                        className="w-full text-left p-5 rounded-2xl border border-neutral-200 bg-white hover:border-aurum hover:bg-rose-gold/5 transition-all group flex justify-between items-center shadow-sm hover:shadow-md"
                                    >
                                        <span className="text-charcoal/90 font-medium">{opt}</span>
                                        <ArrowRight className="w-5 h-5 text-neutral-300 group-hover:text-aurum transition-colors" />
                                    </button>
                                ))}
                            </div>
                        </motion.div>
                    )}
                </div>
            </div>
        </div>
    );
}
