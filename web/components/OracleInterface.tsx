
"use client";

import { useState, useRef, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { Send, Sparkles, User, Bot, AlertCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

type Message = {
    role: 'user' | 'assistant';
    content: string;
};

type Persona = 'mentor' | 'healer' | 'prophet';

export default function OracleInterface() {
    const { t, locale } = useLanguage();
    const [messages, setMessages] = useState<Message[]>([]);
    const [input, setInput] = useState("");
    const [loading, setLoading] = useState(false);
    const [persona, setPersona] = useState<Persona>('mentor');
    const scrollRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [messages, loading]);

    const handleSend = async () => {
        if (!input.trim() || loading) return;

        const userMsg: Message = { role: 'user', content: input };
        setMessages(prev => [...prev, userMsg]);
        setInput("");
        setLoading(true);

        try {
            const res = await fetch('/api/oracle', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: userMsg.content, persona, locale }),
            });

            const data = await res.json();

            if (data.error) {
                setMessages(prev => [...prev, { role: 'assistant', content: `[Error: ${data.error}]` }]);
            } else {
                setMessages(prev => [...prev, { role: 'assistant', content: data.reply }]);
            }
        } catch (err) {
            setMessages(prev => [...prev, { role: 'assistant', content: "The connection to the ether was interrupted." }]);
        } finally {
            setLoading(false);
        }
    };

    const personas = [
        { id: 'mentor', name: t.oracle.roles.mentor, color: 'text-blue-400', border: 'border-blue-400/30' },
        { id: 'healer', name: t.oracle.roles.healer, color: 'text-green-400', border: 'border-green-400/30' },
        { id: 'prophet', name: t.oracle.roles.prophet, color: 'text-purple-400', border: 'border-purple-400/30' },
    ];

    return (
        <div className="w-full max-w-4xl mx-auto min-h-[600px] flex flex-col bg-neutral-900/50 backdrop-blur-xl rounded-3xl border border-neutral-800 shadow-2xl overflow-hidden relative">
            {/* Background Effects */}
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-aurum to-transparent opacity-50" />
            <div className="absolute -top-40 -right-40 w-80 h-80 bg-aurum/10 rounded-full blur-3xl pointer-events-none" />

            {/* Header */}
            <div className="p-6 border-b border-neutral-800 flex flex-col md:flex-row justify-between items-center gap-4 z-10">
                <div>
                    <h2 className="text-2xl font-bold flex items-center gap-2">
                        <Sparkles className="text-aurum w-6 h-6" />
                        {t.oracle.title}
                    </h2>
                    <p className="text-sm text-neutral-400">{t.oracle.subtitle}</p>
                </div>

                <div className="flex gap-2 bg-neutral-950/50 p-1 rounded-full border border-neutral-800">
                    {personas.map(p => (
                        <button
                            key={p.id}
                            onClick={() => setPersona(p.id as Persona)}
                            className={`px-4 py-1.5 rounded-full text-sm transition-all duration-300 ${persona === p.id
                                    ? `bg-neutral-800 ${p.color} shadow-lg`
                                    : 'text-neutral-500 hover:text-neutral-300'
                                }`}
                        >
                            {p.name}
                        </button>
                    ))}
                </div>
            </div>

            {/* Chat Area */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6 scroll-smooth z-10" ref={scrollRef}>
                {messages.length === 0 && (
                    <div className="h-full flex flex-col items-center justify-center text-neutral-500 space-y-4 opacity-70">
                        <Bot className="w-16 h-16 text-neutral-700" />
                        <p>{t.oracle.placeholder}</p>
                    </div>
                )}

                <AnimatePresence mode="popLayout">
                    {messages.map((m, i) => (
                        <motion.div
                            key={i}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            className={`flex gap-4 ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
                        >
                            {m.role === 'assistant' && (
                                <div className={`w-8 h-8 rounded-full flex items-center justify-center bg-neutral-800 border ${personas.find(p => p.id === persona)?.border}`}>
                                    <Sparkles className="w-4 h-4 text-aurum" />
                                </div>
                            )}

                            <div className={`max-w-[80%] p-4 rounded-2xl ${m.role === 'user'
                                    ? 'bg-aurum/10 text-aurum-light border border-aurum/20 rounded-tr-sm'
                                    : 'bg-neutral-800/80 text-neutral-200 border border-neutral-700 rounded-tl-sm'
                                }`}>
                                <p className="leading-relaxed whitespace-pre-wrap">{m.content}</p>
                            </div>

                            {m.role === 'user' && (
                                <div className="w-8 h-8 rounded-full bg-neutral-800 flex items-center justify-center border border-neutral-700">
                                    <User className="w-4 h-4 text-neutral-400" />
                                </div>
                            )}
                        </motion.div>
                    ))}
                </AnimatePresence>

                {loading && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="flex gap-4"
                    >
                        <div className="w-8 h-8 rounded-full flex items-center justify-center bg-neutral-800 border border-neutral-700">
                            <Sparkles className="w-4 h-4 text-aurum animate-pulse" />
                        </div>
                        <div className="bg-neutral-800/50 p-4 rounded-2xl rounded-tl-sm flex gap-2 items-center border border-neutral-800">
                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                        </div>
                    </motion.div>
                )}
            </div>

            {/* Input Area */}
            <div className="p-4 border-t border-neutral-800 bg-neutral-900/80 z-10">
                <form
                    onSubmit={(e) => { e.preventDefault(); handleSend(); }}
                    className="flex gap-4 items-center relative"
                >
                    <input
                        type="text"
                        value={input}
                        onChange={(e) => setInput(e.target.value)}
                        placeholder={t.oracle.placeholder}
                        className="flex-1 bg-neutral-950/50 border border-neutral-700 rounded-full px-6 py-4 focus:outline-none focus:border-aurum/50 focus:ring-1 focus:ring-aurum/20 transition-all text-neutral-200 placeholder-neutral-600"
                        disabled={loading}
                    />
                    <button
                        type="submit"
                        disabled={!input.trim() || loading}
                        className="p-4 rounded-full bg-aurum text-black font-bold hover:bg-aurum-light disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-glow hover:scale-105 active:scale-95"
                    >
                        <Send className="w-5 h-5" />
                    </button>
                </form>
            </div>
        </div>
    );
}
