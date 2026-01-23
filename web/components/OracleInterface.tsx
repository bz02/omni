
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

    // Generate or retrieve threadId
    useEffect(() => {
        let tid = localStorage.getItem('oracle_thread_id');
        if (!tid) {
            tid = crypto.randomUUID();
            localStorage.setItem('oracle_thread_id', tid);
        }
    }, []);

    const handleSend = async () => {
        if (!input.trim() || loading) return;

        const userMsg: Message = { role: 'user', content: input };
        setMessages(prev => [...prev, userMsg]);
        setInput("");
        setLoading(true);

        const threadId = localStorage.getItem('oracle_thread_id');

        try {
            const res = await fetch('/api/oracle', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: userMsg.content, persona, locale, threadId }),
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
        { id: 'mentor', name: t.oracle.roles.mentor },
        { id: 'healer', name: t.oracle.roles.healer },
        { id: 'prophet', name: t.oracle.roles.prophet },
    ];

    return (
        <div className="w-full max-w-4xl mx-auto min-h-[600px] flex flex-col bg-mystic/40 backdrop-blur-2xl rounded-[2rem] border border-white/10 shadow-soft-glow overflow-hidden relative">
            {/* Background Effects */}
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-rose-gold to-transparent opacity-60" />
            <div className="absolute -top-40 -right-40 w-80 h-80 bg-rose-gold/10 rounded-full blur-3xl pointer-events-none" />
            <div className="absolute top-20 left-10 w-40 h-40 bg-aurum/5 rounded-full blur-2xl pointer-events-none" />

            {/* Header */}
            <div className="p-6 border-b border-white/5 flex flex-col md:flex-row justify-between items-center gap-4 z-10 bg-white/5">
                <div>
                    <h2 className="text-2xl font-bold flex items-center gap-2 text-starlight font-display">
                        <Sparkles className="text-rose-gold w-6 h-6" />
                        {t.oracle.title}
                    </h2>
                    <p className="text-sm text-lavender/70">{t.oracle.subtitle}</p>
                </div>

                <div className="flex gap-2 bg-space/40 p-1.5 rounded-full border border-white/10">
                    {personas.map(p => (
                        <button
                            key={p.id}
                            onClick={() => setPersona(p.id as Persona)}
                            className={`px-4 py-1.5 rounded-full text-sm transition-all duration-500 ${persona === p.id
                                ? `bg-gradient-to-r from-mystic to-nebula text-white shadow-lg border border-white/20`
                                : 'text-lavender/60 hover:text-white'
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
                    <div className="h-full flex flex-col items-center justify-center text-lavender/40 space-y-4 opacity-80">
                        <Bot className="w-16 h-16 text-lavender/20" />
                        <p className="font-light tracking-wide">{t.oracle.placeholder}</p>
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
                                <div className={`w-8 h-8 rounded-full flex items-center justify-center bg-mystic border border-white/10 shadow-inner`}>
                                    <Sparkles className="w-4 h-4 text-rose-gold" />
                                </div>
                            )}

                            <div className={`max-w-[80%] p-5 rounded-2xl backdrop-blur-sm ${m.role === 'user'
                                ? 'bg-rose-gold/10 text-starlight border border-rose-gold/20 rounded-tr-sm shadow-sm'
                                : 'bg-white/5 text-starlight/90 border border-white/5 rounded-tl-sm shadow-sm'
                                }`}>
                                <p className="leading-relaxed whitespace-pre-wrap font-light tracking-wide">{m.content}</p>
                            </div>

                            {m.role === 'user' && (
                                <div className="w-8 h-8 rounded-full bg-rose-gold/20 flex items-center justify-center border border-rose-gold/30">
                                    <User className="w-4 h-4 text-rose-gold" />
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
                        <div className="w-8 h-8 rounded-full flex items-center justify-center bg-white border border-rose-gold/20">
                            <Sparkles className="w-4 h-4 text-rose-gold animate-pulse" />
                        </div>
                        <div className="bg-white/60 p-4 rounded-2xl rounded-tl-sm flex gap-2 items-center border border-white/50">
                            <div className="w-2 h-2 bg-rose-gold/50 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                            <div className="w-2 h-2 bg-rose-gold/50 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                            <div className="w-2 h-2 bg-rose-gold/50 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                        </div>
                    </motion.div>
                )}
            </div>

            {/* Input Area */}
            <div className="p-4 border-t border-rose-gold/10 bg-white/40 backdrop-blur-xl z-10">
                <form
                    onSubmit={(e) => { e.preventDefault(); handleSend(); }}
                    className="flex gap-4 items-center relative"
                >
                    <input
                        type="text"
                        value={input}
                        onChange={(e) => setInput(e.target.value)}
                        placeholder={t.oracle.placeholder}
                        className="flex-1 bg-white/60 border border-white/50 rounded-full px-6 py-4 focus:outline-none focus:border-rose-gold/40 focus:bg-white/80 transition-all text-charcoal placeholder-charcoal/40 font-medium shadow-sm"
                        disabled={loading}
                    />
                    <button
                        type="submit"
                        disabled={!input.trim() || loading}
                        className="p-4 rounded-full bg-gradient-to-r from-rose-gold to-aurum text-white font-bold hover:shadow-soft-glow hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md"
                    >
                        <Send className="w-5 h-5" />
                    </button>
                </form>
            </div>
        </div>
    );
}
