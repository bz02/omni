"use client";

import { useState } from "react";
import { MoonStar, Loader2, Info } from "lucide-react";
import clsx from "clsx";
import { motion } from "framer-motion";
import { useLanguage } from "@/contexts/LanguageContext";
import Image from "next/image";

export default function AstrologyPage() {
    const { t, locale } = useLanguage();
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState<any>(null);

    async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
        e.preventDefault();
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
            <div className="fixed inset-0 z-0 pointer-events-none opacity-10 mix-blend-multiply">
                <Image
                    src="/assets/Gemini_Generated_Image_5lv2xh5lv2xh5lv2.png"
                    alt="Space Background"
                    fill
                    className="object-cover"
                />
            </div>

            <div className="relative z-10 max-w-4xl mx-auto space-y-12 py-8">
                <header className="space-y-4 text-center">
                    <h1 className="text-4xl font-bold flex items-center justify-center gap-3 text-charcoal">
                        <MoonStar className="text-aurum w-8 h-8" />
                        {t.astrology.title}
                    </h1>
                    <p className="text-charcoal/60 max-w-xl mx-auto font-medium">
                        {t.astrology.desc}
                    </p>
                </header>

                <div className="grid md:grid-cols-2 gap-8">
                    {/* Input Form */}
                    <div className="bg-white/60 border border-white/50 rounded-2xl p-6 h-fit backdrop-blur-md shadow-sm">
                        <form onSubmit={handleSubmit} className="space-y-4">
                            <h2 className="text-xl font-bold text-charcoal mb-4">{t.astrology.form.title}</h2>

                            <div className="space-y-2">
                                <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.date}</label>
                                <input
                                    name="date"
                                    type="date"
                                    required
                                    className="w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm"
                                    defaultValue="2000-01-01"
                                />
                            </div>

                            <div className="space-y-2">
                                <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.time}</label>
                                <input
                                    name="time"
                                    type="time"
                                    required
                                    className="w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm"
                                    defaultValue="12:00"
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-2">
                                    <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.lat}</label>
                                    <input
                                        name="lat"
                                        placeholder={t.astrology.form.placeholders.lat}
                                        className="w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm placeholder-charcoal/30"
                                    />
                                </div>
                                <div className="space-y-2">
                                    <label className="text-sm text-charcoal/70 font-medium">{t.astrology.form.long}</label>
                                    <input
                                        name="long"
                                        placeholder={t.astrology.form.placeholders.long}
                                        className="w-full bg-white/50 border border-white/60 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors text-charcoal font-medium shadow-sm placeholder-charcoal/30"
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

                    {/* Results Display */}
                    <div className="space-y-6">
                        {!result && !loading && (
                            <div className="h-full flex flex-col items-center justify-center text-charcoal/40 border border-dashed border-rose-gold/20 rounded-2xl p-12 bg-white/30">
                                <Info className="w-10 h-10 mb-4 opacity-50" />
                                <p className="font-medium">{t.astrology.results.empty}</p>
                            </div>
                        )}

                        {result && (
                            <motion.div
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                className="space-y-6"
                            >
                                <div className="bg-white/70 border border-white/60 rounded-2xl p-6 shadow-sm">
                                    <h3 className="text-lg font-bold text-charcoal mb-4 border-b border-rose-gold/10 pb-2">{t.astrology.results.planets}</h3>
                                    <div className="space-y-2 text-sm">
                                        {result.planets.map((p: any) => (
                                            <div key={p.name} className="flex justify-between items-center py-2 border-b border-rose-gold/5 last:border-0 hover:bg-rose-gold/5 px-2 rounded transition-colors">
                                                <span className="font-bold text-charcoal/90">{p.name}</span>
                                                <span className="text-charcoal/70 font-medium">{p.sign} {p.degree.toFixed(1)}° (House {p.house})</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                <div className="bg-white/70 border border-white/60 rounded-2xl p-6 shadow-sm">
                                    <h3 className="text-lg font-bold text-charcoal mb-4 border-b border-rose-gold/10 pb-2">{t.astrology.results.aspects}</h3>
                                    <div className="space-y-2 text-sm">
                                        {result.aspects.map((a: any, i: number) => (
                                            <div key={i} className="flex items-center gap-2 py-1">
                                                <span className="text-charcoal/80 font-medium">{a.planet1}</span>
                                                <span className={clsx(
                                                    "text-xs px-2 py-0.5 rounded border font-semibold",
                                                    a.type === "Trine" || a.type === "Sextile" ? "border-green-200 text-green-700 bg-green-50" :
                                                        a.type === "Square" || a.type === "Opposition" ? "border-red-200 text-red-700 bg-red-50" :
                                                            "border-blue-200 text-blue-700 bg-blue-50"
                                                )}>{a.type}</span>
                                                <span className="text-charcoal/80 font-medium">{a.planet2}</span>
                                                <span className="text-charcoal/50 text-xs ml-auto font-medium">{a.orb.toFixed(1)}° orb</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                <div className="bg-gradient-to-br from-white/80 to-rose-gold/10 border border-white/60 rounded-2xl p-6 relative overflow-hidden shadow-sm">
                                    <div className="absolute top-0 right-0 p-4 opacity-20 pointer-events-none">
                                        <MoonStar className="w-24 h-24 text-rose-gold" />
                                    </div>
                                    <h3 className="text-lg font-bold text-charcoal mb-3 relative z-10">{t.astrology.results.analysis}</h3>
                                    <div className="prose prose-sm max-w-none text-charcoal/80 relative z-10 whitespace-pre-line leading-relaxed font-medium">
                                        {result.analysis}
                                    </div>
                                </div>

                                <div className="flex justify-center pt-4">
                                    <button className="text-sm text-aurum hover:underline underline-offset-4 opacity-90 hover:opacity-100 transition-opacity font-bold uppercase tracking-wider">
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
