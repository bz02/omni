"use client";

import { useState } from "react";
import { Brain, ArrowRight, Loader2 } from "lucide-react";
import { motion } from "framer-motion";
import { useLanguage } from "@/contexts/LanguageContext";
import Image from "next/image";



export default function MBTIPage() {
    const { t, locale } = useLanguage();
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
                <div className="fixed inset-0 z-0 pointer-events-none opacity-20">
                    <Image
                        src="/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png"
                        alt="MBTI Background"
                        fill
                        className="object-cover"
                    />
                    <div className="absolute inset-0 bg-space/85 backdrop-blur-[2px]" />
                </div>

                <div className="relative z-10 max-w-4xl mx-auto space-y-12 py-8">
                    <header className="text-center space-y-4">
                        <h1 className="text-4xl font-bold text-aurum">{t.mbti.profile}: {result.type}</h1>
                        <p className="text-neutral-400">{t.mbti.title}</p>
                    </header>

                    <div className="grid md:grid-cols-2 gap-8">
                        {Object.entries(result.facets).map(([key, val]: [string, any]) => (
                            <div key={key} className="bg-neutral-900/50 border border-neutral-800 p-6 rounded-2xl">
                                <div className="flex justify-between items-center mb-4">
                                    <span className="text-xl font-bold text-white">{key}</span>
                                    <span className="text-aurum font-medium">{val.label} ({val.score}%)</span>
                                </div>
                                <div className="w-full bg-neutral-800 h-2 rounded-full overflow-hidden mb-4">
                                    <div className="bg-aurum h-full transition-all duration-1000" style={{ width: `${val.score}%` }} />
                                </div>
                                <div className="flex flex-wrap gap-2">
                                    {val.facets.map((f: string) => (
                                        <span key={f} className="text-xs bg-neutral-800 px-2 py-1 rounded text-neutral-400">{f}</span>
                                    ))}
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className="bg-gradient-to-r from-nebula/30 to-black border border-aurum/20 p-6 rounded-2xl">
                        <h3 className="text-lg font-semibold text-aurum mb-2">{t.mbti.midZone}</h3>
                        <ul className="list-disc list-inside space-y-2 text-neutral-300">
                            {result.midZones.map((z: string, i: number) => <li key={i}>{z}</li>)}
                        </ul>
                    </div>

                    <div className="text-center text-sm text-neutral-500">
                        {result.evolution}
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="relative min-h-screen flex flex-col">
            {/* Background Image */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-20">
                <Image
                    src="/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png"
                    alt="MBTI Background"
                    fill
                    className="object-cover"
                />
                <div className="absolute inset-0 bg-space/85 backdrop-blur-[2px]" />
            </div>

            <div className="relative z-10 max-w-3xl mx-auto min-h-[60vh] flex flex-col items-center justify-center flex-1">
                {!started ? (
                    <div className="text-center space-y-6">
                        <Brain className="w-16 h-16 text-aurum mx-auto" />
                        <h1 className="text-4xl font-bold">{t.mbti.title}</h1>
                        <p className="text-neutral-400 max-w-lg mx-auto">
                            {t.mbti.desc}
                        </p>
                        <button
                            onClick={() => setStarted(true)}
                            className="px-8 py-3 bg-aurum text-black font-semibold rounded-full hover:opacity-90 transition-all text-lg"
                        >
                            {t.mbti.start}
                        </button>
                    </div>
                ) : loading ? (
                    <div className="flex flex-col items-center gap-4">
                        <Loader2 className="w-10 h-10 animate-spin text-aurum" />
                        <p className="text-neutral-400">{t.mbti.analyzing}</p>
                    </div>
                ) : (
                    <motion.div
                        key={currentQ}
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        className="w-full max-w-xl space-y-8"
                    >
                        <div className="flex justify-between text-sm text-neutral-500">
                            <span>{t.mbti.question} {currentQ + 1} / {questions.length}</span>
                            <span>{Math.round(((currentQ) / questions.length) * 100)}% {t.mbti.complete}</span>
                        </div>

                        <h2 className="text-2xl font-medium text-center">{questions[currentQ].text}</h2>

                        <div className="space-y-4">
                            {questions[currentQ].options.map((opt, idx) => (
                                <button
                                    key={idx}
                                    onClick={() => handleAnswer(idx)}
                                    className="w-full text-left p-4 rounded-xl border border-neutral-800 hover:border-aurum/50 hover:bg-neutral-900/50 transition-all group flex justify-between items-center"
                                >
                                    <span className="text-neutral-300 group-hover:text-white transition-colors">{opt}</span>
                                    <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 text-aurum transition-opacity" />
                                </button>
                            ))}
                        </div>
                    </motion.div>
                )}
            </div>
        </div>
    );
}
