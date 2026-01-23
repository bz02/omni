"use client";

import { useState } from "react";
import { MoonStar, Loader2, Info } from "lucide-react";
import clsx from "clsx";
import { motion } from "framer-motion";
import { useLanguage } from "@/contexts/LanguageContext";

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
        <div className="max-w-4xl mx-auto space-y-12">
            <header className="space-y-4 text-center">
                <h1 className="text-4xl font-bold flex items-center justify-center gap-3">
                    <MoonStar className="text-aurum w-8 h-8" />
                    {t.astrology.title}
                </h1>
                <p className="text-neutral-400 max-w-xl mx-auto">
                    {t.astrology.desc}
                </p>
            </header>

            <div className="grid md:grid-cols-2 gap-8">
                {/* Input Form */}
                <div className="bg-neutral-900/50 border border-neutral-800 rounded-2xl p-6 h-fit bg-gradient-to-b from-neutral-900/50 to-transparent">
                    <form onSubmit={handleSubmit} className="space-y-4">
                        <h2 className="text-xl font-semibold text-aurum mb-4">{t.astrology.form.title}</h2>

                        <div className="space-y-2">
                            <label className="text-sm text-neutral-400">{t.astrology.form.date}</label>
                            <input
                                name="date"
                                type="date"
                                required
                                className="w-full bg-black/40 border border-neutral-800 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors"
                                defaultValue="2000-01-01"
                            />
                        </div>

                        <div className="space-y-2">
                            <label className="text-sm text-neutral-400">{t.astrology.form.time}</label>
                            <input
                                name="time"
                                type="time"
                                required
                                className="w-full bg-black/40 border border-neutral-800 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors"
                                defaultValue="12:00"
                            />
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="space-y-2">
                                <label className="text-sm text-neutral-400">{t.astrology.form.lat}</label>
                                <input
                                    name="lat"
                                    placeholder="e.g. 40.71"
                                    className="w-full bg-black/40 border border-neutral-800 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors"
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm text-neutral-400">{t.astrology.form.long}</label>
                                <input
                                    name="long"
                                    placeholder="e.g. -74.00"
                                    className="w-full bg-black/40 border border-neutral-800 rounded-lg px-4 py-2 focus:border-aurum/50 outline-none transition-colors"
                                />
                            </div>
                        </div>

                        <button
                            disabled={loading}
                            className="w-full bg-aurum text-black font-semibold py-3 rounded-lg hover:bg-aurum/90 transition-all flex items-center justify-center gap-2 mt-4"
                        >
                            {loading ? <Loader2 className="animate-spin w-4 h-4" /> : t.astrology.form.calculate}
                        </button>
                    </form>
                </div>

                {/* Results Display */}
                <div className="space-y-6">
                    {!result && !loading && (
                        <div className="h-full flex flex-col items-center justify-center text-neutral-500 border border-dashed border-neutral-800 rounded-2xl p-12 bg-neutral-900/20">
                            <Info className="w-10 h-10 mb-4 opacity-50" />
                            <p>{t.astrology.results.empty}</p>
                        </div>
                    )}

                    {result && (
                        <motion.div
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            className="space-y-6"
                        >
                            <div className="bg-neutral-900/50 border border-neutral-800 rounded-2xl p-6">
                                <h3 className="text-lg font-semibold text-aurum mb-4 border-b border-neutral-800 pb-2">{t.astrology.results.planets}</h3>
                                <div className="space-y-2 text-sm">
                                    {result.planets.map((p: any) => (
                                        <div key={p.name} className="flex justify-between items-center py-1 border-b border-neutral-800/50 last:border-0 hover:bg-neutral-800/30 px-2 rounded">
                                            <span className="font-medium text-neutral-200">{p.name}</span>
                                            <span className="text-neutral-400">{p.sign} {p.degree.toFixed(1)}° (House {p.house})</span>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            <div className="bg-neutral-900/50 border border-neutral-800 rounded-2xl p-6">
                                <h3 className="text-lg font-semibold text-aurum mb-4 border-b border-neutral-800 pb-2">{t.astrology.results.aspects}</h3>
                                <div className="space-y-2 text-sm">
                                    {result.aspects.map((a: any, i: number) => (
                                        <div key={i} className="flex items-center gap-2 py-1">
                                            <span className="text-neutral-300">{a.planet1}</span>
                                            <span className={clsx(
                                                "text-xs px-2 py-0.5 rounded border",
                                                a.type === "Trine" || a.type === "Sextile" ? "border-green-800 text-green-400 bg-green-900/20" :
                                                    a.type === "Square" || a.type === "Opposition" ? "border-red-800 text-red-400 bg-red-900/20" :
                                                        "border-blue-800 text-blue-400 bg-blue-900/20"
                                            )}>{a.type}</span>
                                            <span className="text-neutral-300">{a.planet2}</span>
                                            <span className="text-neutral-500 text-xs ml-auto">{a.orb.toFixed(1)}° orb</span>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            <div className="bg-gradient-to-br from-nebula/20 to-neutral-900 border border-aurum/20 rounded-2xl p-6 relative overflow-hidden">
                                <div className="absolute top-0 right-0 p-4 opacity-10">
                                    <MoonStar className="w-24 h-24 text-aurum" />
                                </div>
                                <h3 className="text-lg font-semibold text-aurum mb-3 relative z-10">{t.astrology.results.analysis}</h3>
                                <div className="prose prose-invert prose-sm max-w-none text-neutral-300 relative z-10 whitespace-pre-line leading-relaxed">
                                    {result.analysis}
                                </div>
                            </div>

                            <div className="flex justify-center pt-4">
                                <button className="text-sm text-aurum hover:underline underline-offset-4 opacity-80 hover:opacity-100 transition-opacity">
                                    {t.astrology.results.download}
                                </button>
                            </div>
                        </motion.div>
                    )}
                </div>
            </div>
        </div>
    );
}
