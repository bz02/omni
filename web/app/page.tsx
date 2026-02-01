"use client";

import { Brain, Compass, HandCoins, MoonStar, Sparkles } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useLanguage } from "../contexts/LanguageContext";
import { useUsage } from "../contexts/UsageContext";
import OracleInterface from "../components/OracleInterface";
import { useState } from "react";

export default function Home() {
  const { t } = useLanguage();
  const { openPaywall } = useUsage();

  const quickFeatures = [
    { title: t.home.features.astro, body: t.astrology.desc, icon: <MoonStar className="text-aurum" />, link: "/astrology" },
    { title: t.home.features.tarot, body: t.tarot.desc, icon: <Compass className="text-aurum" />, link: "/tarot" },
    { title: t.home.features.mbti, body: t.mbti.desc, icon: <Brain className="text-aurum" />, link: "/mbti" },
  ];

  return (
    <div className="space-y-12">
      {/* Hero / Oracle Section */}
      <section className="relative py-10">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[500px] opacity-40 pointer-events-none z-0">
          <div className="relative w-full h-full">
            <Image src="/assets/Gemini_Generated_Image_ae247sae247sae24.png" alt="Aura" fill className="object-cover blur-3xl rounded-full" />
          </div>
        </div>

        <div className="relative z-10 text-center mb-10 space-y-6">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/60 border border-rose-gold/40 text-charcoal/80 text-xs uppercase tracking-widest backdrop-blur-md shadow-sm">
            <Sparkles className="w-3 h-3 text-rose-gold" />
            <span>Omni Oracle Online</span>
          </div>
          <h1 className="text-5xl md:text-7xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-rose-gold via-charcoal to-lavender drop-shadow-sm font-display leading-tight">
            {t.home.heroTitle}
          </h1>
          <p className="text-charcoal/70 max-w-2xl mx-auto text-lg md:text-xl font-light leading-relaxed">
            {t.home.heroDesc}
          </p>
        </div>

        <OracleInterface />

        <div className="mt-8 flex justify-center gap-4">
          <button
            onClick={() => openPaywall()}
            className="flex items-center gap-2 px-6 py-3 rounded-full bg-white/80 hover:bg-white border border-rose-gold/30 hover:border-aurum/50 transition-all text-charcoal hover:text-charcoal shadow-sm hover:shadow-md"
          >
            <HandCoins className="w-4 h-4 text-aurum" />
            {t.home.features.tips}
          </button>
        </div>
      </section>

      {/* Feature Grid */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-12 border-t border-rose-gold/10">
        {[
          {
            title: t.home.features.astro,
            body: t.astrology.desc,
            icon: <MoonStar className="text-aurum w-6 h-6" />,
            link: "/astrology",
            img: "/assets/Gemini_Generated_Image_5lv2xh5lv2xh5lv2.png"
          },
          {
            title: t.home.features.tarot,
            body: t.tarot.desc,
            icon: <Compass className="text-aurum w-6 h-6" />,
            link: "/tarot",
            img: "/assets/Gemini_Generated_Image_d51vljd51vljd51v.png"
          },
          {
            title: t.home.features.mbti,
            body: t.mbti.desc,
            icon: <Brain className="text-aurum w-6 h-6" />,
            link: "/mbti",
            img: "/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png"
          },
        ].filter(f => f.link !== "/mbti" && f.link !== "/tarot").map((f, i) => (
          <Link key={i} href={f.link} className="relative group overflow-hidden rounded-3xl h-80 block border border-white/40 shadow-sm hover:shadow-soft-glow transition-all duration-500 bg-white/50">
            {/* Background Image */}
            <div className="absolute inset-0">
              <Image
                src={f.img}
                alt={f.title}
                fill
                className="object-cover transition-transform duration-700 group-hover:scale-110 opacity-30 group-hover:opacity-20 mix-blend-multiply"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-white/90 via-white/50 to-transparent" />
            </div>

            {/* Content */}
            <div className="absolute bottom-0 left-0 right-0 p-8 space-y-4">
              <div className="inline-flex p-3 rounded-2xl bg-white/60 backdrop-blur-md border border-white/50 group-hover:bg-aurum/10 group-hover:border-aurum/30 transition-colors shadow-sm">
                {f.icon}
              </div>
              <div>
                <h3 className="text-2xl font-bold text-charcoal mb-2 font-display">{f.title}</h3>
                <p className="text-sm text-charcoal/70 line-clamp-3 leading-relaxed font-medium">{f.body}</p>
              </div>

              <div className="flex items-center gap-2 text-rose-gold text-sm font-semibold tracking-wider opacity-0 group-hover:opacity-100 transform translate-y-4 group-hover:translate-y-0 transition-all duration-300">
                <span>Explore</span>
                <Sparkles className="w-4 h-4" />
              </div>
            </div>
          </Link>
        ))}
      </section>
    </div>
  );
}


