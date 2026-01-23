"use client";

import { Brain, Compass, HandCoins, MoonStar, Sparkles } from "lucide-react";
import Link from "next/link";
import { useLanguage } from "../contexts/LanguageContext";
import OracleInterface from "../components/OracleInterface";
import PaymentModal from "../components/PaymentModal";
import { useState } from "react";

export default function Home() {
  const { t } = useLanguage();
  const [showPayment, setShowPayment] = useState(false);

  const quickFeatures = [
    { title: t.home.features.astro, body: t.astrology.desc, icon: <MoonStar className="text-aurum" />, link: "/astrology" },
    { title: t.home.features.tarot, body: t.tarot.desc, icon: <Compass className="text-aurum" />, link: "/tarot" },
    { title: t.home.features.mbti, body: t.mbti.desc, icon: <Brain className="text-aurum" />, link: "/mbti" },
  ];

  return (
    <div className="space-y-12">
      <PaymentModal isOpen={showPayment} onClose={() => setShowPayment(false)} />

      {/* Hero / Oracle Section */}
      <section className="relative">
        <div className="text-center mb-8 space-y-4">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-aurum/10 border border-aurum/20 text-aurum text-xs uppercase tracking-widest">
            <Sparkles className="w-3 h-3" />
            <span>Omni Oracle Online</span>
          </div>
          <h1 className="text-4xl md:text-6xl font-bold bg-clip-text text-transparent bg-gradient-to-b from-white to-neutral-500">
            {t.home.heroTitle}
          </h1>
          <p className="text-neutral-400 max-w-2xl mx-auto text-lg">
            {t.home.heroDesc}
          </p>
        </div>

        <OracleInterface />

        <div className="mt-8 flex justify-center gap-4">
          <button
            onClick={() => setShowPayment(true)}
            className="flex items-center gap-2 px-6 py-3 rounded-full bg-neutral-800 hover:bg-neutral-700 border border-neutral-700 hover:border-aurum/50 transition-all text-neutral-300 hover:text-white"
          >
            <HandCoins className="w-4 h-4 text-aurum" />
            {t.home.features.tips}
          </button>
        </div>
      </section>

      {/* Feature Grid */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-12 border-t border-neutral-900">
        {quickFeatures.map((f, i) => (
          <Link key={i} href={f.link || "#"} className="card space-y-3 group hover:border-aurum/40 transition-all hover:-translate-y-1 block">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-neutral-900 rounded-lg group-hover:bg-neutral-800 transition-colors">{f.icon}</div>
              <h3 className="font-semibold">{f.title}</h3>
            </div>
            <p className="text-sm text-neutral-400">{f.body}</p>
          </Link>
        ))}
      </section>
    </div>
  );
}


