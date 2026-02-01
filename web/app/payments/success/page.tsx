"use client";

import { useSearchParams } from "next/navigation";
import { CheckCircle2, Heart } from "lucide-react";
import { motion } from "framer-motion";
import Link from "next/link";
import { useEffect } from "react";
import canvasConfetti from 'canvas-confetti';

export default function PaymentSuccessPage() {
    const searchParams = useSearchParams();
    const sessionId = searchParams.get("session_id");

    useEffect(() => {
        if (sessionId) {
            canvasConfetti({
                particleCount: 150,
                spread: 70,
                origin: { y: 0.6 },
                colors: ['#D4AF37', '#FFD700', '#F0E68C']
            });
        }
    }, [sessionId]);

    return (
        <div className="max-w-xl mx-auto min-h-[60vh] flex flex-col items-center justify-center text-center space-y-6">
            <motion.div
                initial={{ scale: 0.5, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="w-24 h-24 bg-green-500/20 text-green-400 rounded-full flex items-center justify-center shadow-[0_0_30px_rgba(0,255,0,0.3)]"
            >
                <CheckCircle2 className="w-12 h-12" />
            </motion.div>

            <div className="space-y-2">
                <h1 className="text-4xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-400">Payment Successful!</h1>
                <p className="text-neutral-400">Thank you for your generous support. Your payment has been processed securely.</p>
            </div>

            <div className="pt-8">
                <Link
                    href="/"
                    className="px-8 py-3 bg-neutral-800 hover:bg-neutral-700 rounded-xl transition-colors text-white font-medium"
                >
                    Return Home
                </Link>
            </div>
        </div>
    );
}
