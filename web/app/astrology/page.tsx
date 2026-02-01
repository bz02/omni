"use client";

import { useState } from "react";
import { MoonStar, Loader2, Info, MapPin } from "lucide-react";
import clsx from "clsx";
import { motion } from "framer-motion";
import { useLanguage } from "@/contexts/LanguageContext";
import { useUsage } from "@/contexts/UsageContext";
import Image from "next/image";
import ReactMarkdown from 'react-markdown';

export default function AstrologyPage() {
    const { t, locale } = useLanguage();
    const { incrementFeature } = useUsage();
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState<any>(null);

    async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
        e.preventDefault();

        // Enforce Limit
        if (!incrementFeature()) return;

        setLoading(true);
        const formData = new FormData(e.currentTarget);
        const data = Object.fromEntries(formData.entries());

        try {
            const res = await fetch("/api/astrology", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ ...data, locale }),
            });
            const json = await res.json();
            setResult(json);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="relative min-h-screen">
            {/* Background Image */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-5">
                <Image
                    src="/assets/Gemini_Generated_Image_5lv2xh5lv2xh5lv2.png"
                    alt="Space Background"
                    fill
                    className="object-cover"
                />
            </div>

            <div className="relative z-10 max-w-5xl mx-auto space-y-12 py-8 px-4">
                <header className="space-y-4 text-center">
                    <h1 className="text-4xl font-bold flex items-center justify-center gap-3 text-charcoal">
                        <MoonStar className="text-aurum w-8 h-8" />
                        {t.astrology.title}
                    </h1>
                    <p className="text-charcoal/60 max-w-xl mx-auto font-medium">
                        {t.astrology.desc}
                    </p>
                </header>

                <div className="grid md:grid-cols-12 gap-8">
                    {/* Input Form */}
                    <div className="md:col-span-4 h-fit min-w-0 print:hidden">
                        <div className="bg-white/60 border border-white/50 rounded-2xl p-4 md:p-6 backdrop-blur-md shadow-sm md:sticky md:top-8">
                            <form onSubmit={handleSubmit} className="space-y-4">
                                <h2 className="text-xl font-bold text-charcoal mb-4">{t.astrology.form.title}</h2>

                                <div className="space-y-2">
                                    <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.date}</label>
                                    <input
                                        name="date"
                                        type="date"
                                        required
                                        className="w-full max-w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm"
                                        defaultValue="1995-01-01"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.time}</label>
                                    <input
                                        name="time"
                                        type="time"
                                        required
                                        className="w-full max-w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm"
                                        defaultValue="12:00"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-sm text-charcoal/70 font-medium">{locale === 'zh' ? "出生地点" : "Birth Place"}</label>
                                    <div className="relative">
                                        <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-charcoal/40" />
                                        <input
                                            name="place"
                                            placeholder={locale === 'zh' ? "例如：北京, 中国" : "e.g. New York, USA"}
                                            required
                                            className="w-full max-w-full bg-white/50 border border-white/60 rounded-lg pl-10 pr-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm placeholder-charcoal/30"
                                        />
                                    </div>
                                </div>

                                <button
                                    disabled={loading}
                                    className="w-full bg-gradient-to-r from-rose-gold to-aurum text-white font-bold py-3 rounded-lg hover:shadow-soft-glow transition-all flex items-center justify-center gap-2 mt-4 shadow-md"
                                >
                                    {loading ? <Loader2 className="animate-spin w-4 h-4 text-white" /> : t.astrology.form.calculate}
                                </button>
                            </form>
                        </div>
                    </div>

                    {/* Results Display */}
                    <div className="md:col-span-8 min-h-[50vh]">
                        {!result && !loading && (
                            <div className="h-full flex flex-col items-center justify-center text-charcoal/40 border border-dashed border-rose-gold/20 rounded-2xl p-12 bg-white/30">
                                <Info className="w-10 h-10 mb-4 opacity-50" />
                                <p className="font-medium">{t.astrology.results.empty}</p>
                            </div>
                        )}

                        {loading && (
                            <div className="h-full flex flex-col items-center justify-center text-charcoal/60 space-y-4">
                                <Loader2 className="w-10 h-10 animate-spin text-aurum" />
                                <p className="animate-pulse font-medium">{locale === 'zh' ? "正在以此辰此地沟通天地..." : "Consulting the stars and the elements..."}</p>
                            </div>
                        )}

                        {result && (
                            <motion.div
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                className="bg-white/70 border border-white/60 rounded-3xl p-8 shadow-sm relative overflow-hidden"
                            >
                                <div className="absolute top-0 right-0 p-8 opacity-10 pointer-events-none print:hidden">
                                    <MoonStar className="w-40 h-40 text-rose-gold" />
                                </div>

                                <div className="prose prose-stone max-w-none prose-headings:font-bold prose-headings:text-charcoal prose-p:text-charcoal/80 prose-strong:text-charcoal/90 prose-strong:font-bold relative z-10 print:text-black">
                                    <ReactMarkdown>{result.content}</ReactMarkdown>
                                </div>

                                <div className="flex justify-center pt-8 border-t border-charcoal/5 mt-8">
                                    <button
                                        onClick={() => window.print()}
                                        className="text-sm text-aurum hover:underline underline-offset-4 opacity-90 hover:opacity-100 transition-opacity font-bold uppercase tracking-wider print:hidden"
                                    >
                                        {t.astrology.results.download}
                                    </button>
                                </div>
                            </motion.div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
