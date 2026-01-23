"use client";

import { useState } from "react";
import { HandCoins, CreditCard, CheckCircle2, Loader2, Sparkles } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import canvasConfetti from 'canvas-confetti';
import clsx from "clsx";
import { useLanguage } from "@/contexts/LanguageContext";

const tipAmounts = [5.55, 11.11, 22.22, 33.33, 88.88];

export default function PaymentsPage() {
    const { t } = useLanguage();
    const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
    const [customAmount, setCustomAmount] = useState("");
    const [loading, setLoading] = useState(false);
    const [success, setSuccess] = useState(false);

    const handleTip = async () => {
        const amount = selectedAmount || parseFloat(customAmount);
        if (!amount || amount <= 0) return;

        setLoading(true);
        try {
            const res = await fetch("/api/payments", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ amount }),
            });

            if (res.ok) {
                setSuccess(true);
                canvasConfetti({
                    particleCount: 100,
                    spread: 70,
                    origin: { y: 0.6 },
                    colors: ['#D4AF37', '#F8F8FF', '#2D004B']
                });
            }
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    if (success) {
        return (
            <div className="max-w-xl mx-auto min-h-[60vh] flex flex-col items-center justify-center text-center space-y-6">
                <motion.div
                    initial={{ scale: 0.5, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    className="w-20 h-20 bg-green-500/20 text-green-400 rounded-full flex items-center justify-center"
                >
                    <CheckCircle2 className="w-10 h-10" />
                </motion.div>
                <h2 className="text-3xl font-bold">{t.payments.thankYou}</h2>
                <p className="text-neutral-400">{t.payments.thankYouDesc}</p>
                <button
                    onClick={() => { setSuccess(false); setSelectedAmount(null); setCustomAmount(""); }}
                    className="text-aurum hover:underline"
                >
                    {t.payments.again}
                </button>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto space-y-8">
            <header className="text-center space-y-4">
                <h1 className="text-4xl font-bold flex items-center justify-center gap-3 text-aurum">
                    <HandCoins className="w-8 h-8" />
                    {t.payments.title}
                </h1>
                <p className="text-neutral-400">
                    {t.payments.desc}
                </p>
            </header>

            <div className="bg-neutral-900/50 border border-neutral-800 rounded-2xl p-8 space-y-8">
                <div className="space-y-4">
                    <label className="text-sm font-medium text-neutral-300">{t.payments.select}</label>
                    <div className="grid grid-cols-3 gap-3">
                        {tipAmounts.map((amt) => (
                            <button
                                key={amt}
                                onClick={() => { setSelectedAmount(amt); setCustomAmount(""); }}
                                className={clsx(
                                    "py-3 rounded-xl border transition-all font-semibold",
                                    selectedAmount === amt
                                        ? "bg-aurum text-black border-aurum"
                                        : "bg-black/40 border-neutral-800 text-neutral-400 hover:border-aurum/50 hover:text-white"
                                )}
                            >
                                ${amt}
                            </button>
                        ))}
                        <div className="relative col-span-1">
                            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-neutral-500">$</span>
                            <input
                                type="number"
                                placeholder={t.payments.custom}
                                value={customAmount}
                                onChange={(e) => { setCustomAmount(e.target.value); setSelectedAmount(null); }}
                                className={clsx(
                                    "w-full h-full bg-black/40 border rounded-xl pl-6 pr-2 focus:outline-none transition-colors",
                                    customAmount ? "border-aurum text-white" : "border-neutral-800 text-neutral-400"
                                )}
                            />
                        </div>
                    </div>
                </div>

                <div className="space-y-4">
                    <label className="text-sm font-medium text-neutral-300">{t.payments.method}</label>
                    <div className="p-4 border border-neutral-800 rounded-xl bg-black/20 flex items-center gap-3 text-neutral-400">
                        <CreditCard className="w-5 h-5" />
                        <span>Card ending in 4242 (Mock)</span>
                        <span className="ml-auto text-xs bg-neutral-800 px-2 py-1 rounded">Default</span>
                    </div>
                </div>

                <button
                    onClick={handleTip}
                    disabled={loading || (!selectedAmount && !customAmount)}
                    className="w-full bg-gradient-to-r from-aurum to-amber-600 text-black font-bold py-4 rounded-xl shadow-glow hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                    {loading ? <Loader2 className="animate-spin" /> : <><Sparkles className="w-4 h-4" /> {t.payments.send}</>}
                </button>

                <p className="text-xs text-center text-neutral-500 flex items-center justify-center gap-1">
                    <CheckCircle2 className="w-3 h-3" />
                    {t.payments.secure}
                </p>
            </div>
        </div>
    );
}
