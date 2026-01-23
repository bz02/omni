"use client";

import { useState, useRef, useEffect } from "react";
import { MessageSquare, Mic, Send, Bot, Sparkles } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import clsx from "clsx";
import { useLanguage } from "@/contexts/LanguageContext";

export default function OraclePage() {
    const { t, locale } = useLanguage();

    const personas = [
        { id: "Rational Mentor", name: t.oracle.roles.mentor, desc: "Logic & Strategy", color: "bg-blue-900/40 text-blue-200 border-blue-800" },
        { id: "Gentle Healer", name: t.oracle.roles.healer, desc: "Empathy & Support", color: "bg-emerald-900/40 text-emerald-200 border-emerald-800" },
        { id: "Cold Prophet", name: t.oracle.roles.prophet, desc: "Truth & Objective", color: "bg-neutral-900/80 text-neutral-200 border-neutral-700" },
    ];

    const [messages, setMessages] = useState<{ role: 'user' | 'assistant', text: string }[]>([]);
    const [input, setInput] = useState("");
    const [loading, setLoading] = useState(false);
    const [selectedPersona, setSelectedPersona] = useState(personas[0]);
    const chatEndRef = useRef<HTMLDivElement>(null);

    // Initialize welcome message when language changes
    useEffect(() => {
        if (messages.length === 0) {
            setMessages([{ role: 'assistant', text: locale === 'zh' ? "我是 Omni 神谕。选择一个角色，问我任何关于你道路的问题。" : "I am the Omni Oracle. Choose a persona and ask me anything about your path." }]);
        }
    }, [messages.length, locale]); // NOTE: This isn't perfect for auto-translating history, but good enough for a welcome msg

    useEffect(() => {
        chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages]);

    // Update persona labels on lang switch
    const currentPersonaLabel = personas.find(p => p.id === selectedPersona.id) || selectedPersona;

    async function handleSend() {
        if (!input.trim()) return;

        const userMsg = input;
        setMessages(prev => [...prev, { role: 'user', text: userMsg }]);
        setInput("");
        setLoading(true);

        try {
            const res = await fetch("/api/oracle", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ message: userMsg, persona: selectedPersona.id, locale }),
            });
            const json = await res.json();
            setMessages(prev => [...prev, { role: 'assistant', text: json.reply }]);
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="max-w-4xl mx-auto h-[80vh] flex flex-col gap-6">
            <header className="flex flex-col md:flex-row gap-4 items-center justify-between shrink-0">
                <div>
                    <h1 className="text-2xl font-bold flex items-center gap-2 text-aurum">
                        <Sparkles className="w-6 h-6" /> {t.oracle.title}
                    </h1>
                    <p className="text-sm text-neutral-400">{t.oracle.subtitle}</p>
                </div>

                <div className="flex gap-2">
                    {personas.map(p => (
                        <button
                            key={p.id}
                            onClick={() => setSelectedPersona(p)}
                            className={clsx(
                                "px-3 py-1.5 rounded-full text-xs border transition-all",
                                selectedPersona.id === p.id ? "ring-2 ring-aurum border-transparent" : "opacity-60 hover:opacity-100",
                                p.color
                            )}
                        >
                            <div className="font-semibold">{p.name}</div>
                        </button>
                    ))}
                </div>
            </header>

            <div className="flex-1 overflow-y-auto bg-neutral-900/30 border border-neutral-800 rounded-2xl p-4 space-y-4 scrollbar-thin">
                {messages.map((m, i) => (
                    <motion.div
                        key={i}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        className={clsx(
                            "flex gap-3 max-w-[80%]",
                            m.role === 'user' ? "ml-auto flex-row-reverse" : ""
                        )}
                    >
                        <div className={clsx(
                            "w-8 h-8 rounded-full flex items-center justify-center shrink-0",
                            m.role === 'user' ? "bg-aurum text-black" : "bg-neutral-800 text-white"
                        )}>
                            {m.role === 'user' ? "You" : <Bot className="w-5 h-5" />}
                        </div>
                        <div className={clsx(
                            "p-3 rounded-2xl text-sm leading-relaxed",
                            m.role === 'user' ? "bg-aurum/10 text-aurum border border-aurum/20" : "bg-neutral-800 text-neutral-200"
                        )}>
                            {m.text}
                        </div>
                    </motion.div>
                ))}
                {loading && (
                    <div className="flex gap-3">
                        <div className="w-8 h-8 rounded-full bg-neutral-800 flex items-center justify-center">
                            <Bot className="w-5 h-5 text-neutral-500" />
                        </div>
                        <div className="flex items-center gap-1 h-10 px-3 bg-neutral-800 rounded-2xl">
                            <span className="w-1.5 h-1.5 bg-neutral-500 rounded-full animate-bounce [animation-delay:-0.3s]"></span>
                            <span className="w-1.5 h-1.5 bg-neutral-500 rounded-full animate-bounce [animation-delay:-0.15s]"></span>
                            <span className="w-1.5 h-1.5 bg-neutral-500 rounded-full animate-bounce"></span>
                        </div>
                    </div>
                )}
                <div ref={chatEndRef} />
            </div>

            <div className="shrink-0 relative">
                <input
                    value={input}
                    onChange={e => setInput(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && handleSend()}
                    placeholder={t.oracle.placeholder}
                    className="w-full bg-neutral-900 border border-neutral-800 rounded-xl pl-4 pr-32 py-4 focus:border-aurum/50 outline-none transition-colors shadow-lg"
                />
                <div className="absolute right-2 top-2 bottom-2 flex gap-1">
                    <button className="p-2 text-neutral-400 hover:text-white rounded-lg hover:bg-neutral-800 transition-colors">
                        <Mic className="w-5 h-5" />
                    </button>
                    <button
                        onClick={handleSend}
                        disabled={!input.trim() || loading}
                        className="px-4 bg-aurum text-black rounded-lg font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <Send className="w-5 h-5" />
                    </button>
                </div>
            </div>
        </div>
    );
}
