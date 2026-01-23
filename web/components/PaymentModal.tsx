
"use client";

import { useState } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { X, CreditCard, Heart, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';

interface PaymentModalProps {
    isOpen: boolean;
    onClose: () => void;
}

export default function PaymentModal({ isOpen, onClose }: PaymentModalProps) {
    const { t } = useLanguage();
    const [amount, setAmount] = useState<number | null>(null);
    const [customAmount, setCustomAmount] = useState("");
    const [processing, setProcessing] = useState(false);
    const [step, setStep] = useState<'select' | 'processing' | 'success'>('select');

    if (!isOpen) return null;

    const handlePayment = async () => {
        const finalAmount = amount || Number(customAmount);
        if (!finalAmount || finalAmount <= 0) return;

        setProcessing(true);
        // setStep('processing'); // You can show a specific processing step if you want

        try {
            const res = await fetch('/api/payments', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ amount: finalAmount }),
            });

            if (res.ok) {
                setStep('success');
                confetti({
                    particleCount: 100,
                    spread: 70,
                    origin: { y: 0.6 },
                    colors: ['#D4AF37', '#FFD700', '#F0E68C'] // Aurum colors
                });
            } else {
                alert("Payment failed (mock)");
            }
        } catch (e) {
            console.error(e);
        } finally {
            setProcessing(false);
        }
    };

    const presetAmounts = [5, 10, 20];

    return (
        <AnimatePresence>
            {isOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        onClick={onClose}
                        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
                    />

                    <motion.div
                        initial={{ scale: 0.9, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        exit={{ scale: 0.9, opacity: 0 }}
                        className="bg-neutral-900 border border-neutral-800 rounded-3xl p-8 w-full max-w-md relative shadow-2xl z-10 overflow-hidden"
                    >
                        <button
                            onClick={onClose}
                            className="absolute top-4 right-4 p-2 hover:bg-neutral-800 rounded-full transition-colors text-neutral-400"
                        >
                            <X className="w-5 h-5" />
                        </button>

                        <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-aurum to-transparent opacity-50" />

                        {step === 'select' && (
                            <div className="space-y-6">
                                <div className="text-center space-y-2">
                                    <div className="w-16 h-16 bg-aurum/10 rounded-full flex items-center justify-center mx-auto mb-4 border border-aurum/20">
                                        <Heart className="w-8 h-8 text-aurum fill-aurum/20" />
                                    </div>
                                    <h3 className="text-2xl font-bold">{t.payments.title}</h3>
                                    <p className="text-neutral-400 text-sm">{t.payments.desc}</p>
                                </div>

                                <div className="grid grid-cols-3 gap-3">
                                    {presetAmounts.map(amt => (
                                        <button
                                            key={amt}
                                            onClick={() => { setAmount(amt); setCustomAmount(""); }}
                                            className={`py-3 rounded-xl border transition-all ${amount === amt
                                                    ? 'bg-aurum text-black border-aurum font-bold shadow-glow'
                                                    : 'bg-neutral-800 border-neutral-700 hover:border-aurum/50'
                                                }`}
                                        >
                                            ${amt}
                                        </button>
                                    ))}
                                </div>

                                <div className="relative">
                                    <span className="absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400">$</span>
                                    <input
                                        type="number"
                                        placeholder={t.payments.custom}
                                        value={customAmount}
                                        onChange={(e) => {
                                            setCustomAmount(e.target.value);
                                            setAmount(null);
                                        }}
                                        className={`w-full bg-neutral-950 border rounded-xl py-3 pl-8 pr-4 focus:outline-none transition-colors ${customAmount ? 'border-aurum text-aurum' : 'border-neutral-700 text-neutral-200'
                                            }`}
                                    />
                                </div>

                                <button
                                    onClick={handlePayment}
                                    disabled={(!amount && !customAmount) || processing}
                                    className="w-full py-4 rounded-xl bg-gradient-to-r from-aurum to-amber-300 text-black font-bold text-lg shadow-glow hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-50 disabled:scale-100 flex items-center justify-center gap-2"
                                >
                                    {processing ? (
                                        <Loader2 className="animate-spin w-5 h-5" />
                                    ) : (
                                        <>
                                            <CreditCard className="w-5 h-5" />
                                            {t.payments.send}
                                        </>
                                    )}
                                </button>

                                <p className="text-xs text-center text-neutral-500 flex items-center justify-center gap-1">
                                    <CreditCard className="w-3 h-3" />
                                    {t.payments.secure}
                                </p>
                            </div>
                        )}

                        {step === 'success' && (
                            <div className="text-center space-y-6 py-8">
                                <motion.div
                                    initial={{ scale: 0 }}
                                    animate={{ scale: 1 }}
                                    className="w-20 h-20 bg-green-500/10 rounded-full flex items-center justify-center mx-auto border border-green-500/30 text-green-400"
                                >
                                    <Heart className="w-10 h-10 fill-current" />
                                </motion.div>
                                <div className="space-y-2">
                                    <h3 className="text-2xl font-bold text-white">{t.payments.thankYou}</h3>
                                    <p className="text-neutral-400">{t.payments.thankYouDesc}</p>
                                </div>
                                <button
                                    onClick={() => setStep('select')}
                                    className="text-aurum hover:text-aurum-light text-sm underline underline-offset-4"
                                >
                                    {t.payments.again}
                                </button>
                            </div>
                        )}
                    </motion.div>
                </div>
            )}
        </AnimatePresence>
    );
}
