"use client";

import { XCircle } from "lucide-react";
import { motion } from "framer-motion";
import Link from "next/link";

export default function PaymentCancelPage() {
    return (
        <div className="max-w-xl mx-auto min-h-[60vh] flex flex-col items-center justify-center text-center space-y-6">
            <motion.div
                initial={{ scale: 0.5, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="w-24 h-24 bg-red-500/20 text-red-400 rounded-full flex items-center justify-center shadow-[0_0_30px_rgba(255,0,0,0.2)]"
            >
                <XCircle className="w-12 h-12" />
            </motion.div>

            <div className="space-y-2">
                <h1 className="text-4xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-neutral-400">Payment Cancelled</h1>
                <p className="text-neutral-400">You have cancelled the payment process. No charges were made.</p>
            </div>

            <div className="pt-8 flex gap-4 justify-center">
                <Link
                    href="/"
                    className="px-8 py-3 bg-neutral-800 hover:bg-neutral-700 rounded-xl transition-colors text-white font-medium"
                >
                    Return Home
                </Link>
                <Link
                    href="/payments"
                    className="px-8 py-3 bg-aurum/10 hover:bg-aurum/20 border border-aurum/50 text-aurum rounded-xl transition-colors font-medium"
                >
                    Try Again
                </Link>
            </div>
        </div>
    );
}
