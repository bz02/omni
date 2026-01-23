
"use client";

import { signIn } from "next-auth/react";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Lock, User } from "lucide-react";
import Image from "next/image";

export default function LoginPage() {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    const router = useRouter();
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        const result = await signIn("credentials", {
            username,
            password,
            redirect: false,
        });

        if (result?.ok) {
            router.push("/");
        } else {
            setLoading(false);
            alert("Login failed");
        }
    };

    const handleGuest = async () => {
        setLoading(true);
        // We can just redirect to home, or sign in as a specific guest user if we want session persistence
        // For now, let's treat Guest as just a username "Guest"
        const result = await signIn("credentials", {
            username: "Guest",
            password: "password", // Dummy password
            redirect: false,
        });
        if (result?.ok) {
            router.push("/");
        } else {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen relative flex items-center justify-center p-4">
            {/* Background Image */}
            <div className="fixed inset-0 z-0 pointer-events-none opacity-20 mix-blend-multiply">
                <Image
                    src="/assets/Gemini_Generated_Image_ae247sae247sae24.png"
                    alt="Login Background"
                    fill
                    className="object-cover"
                />
            </div>

            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="relative z-10 w-full max-w-md bg-white/60 border border-white/40 backdrop-blur-xl p-8 rounded-3xl shadow-soft-glow"
            >
                <div className="text-center mb-8">
                    <h1 className="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-aurum to-rose-gold mb-2">Welcome to Omni</h1>
                    <p className="text-charcoal/60 text-sm font-medium">Sign in to sync your destiny</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <div className="space-y-2">
                        <label className="text-xs uppercase tracking-widest text-charcoal/60 font-bold ml-2">Username</label>
                        <div className="relative">
                            <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-charcoal/40" />
                            <input
                                type="text"
                                value={username}
                                onChange={(e) => setUsername(e.target.value)}
                                className="w-full bg-white/40 border border-white/60 rounded-xl py-3 pl-12 pr-4 text-charcoal focus:border-rose-gold/50 focus:bg-white/80 outline-none transition-all placeholder-charcoal/30 shadow-sm font-medium"
                                placeholder="Enter username"
                                required
                            />
                        </div>
                    </div>

                    <div className="space-y-2">
                        <label className="text-xs uppercase tracking-widest text-charcoal/60 font-bold ml-2">Password</label>
                        <div className="relative">
                            <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-charcoal/40" />
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="w-full bg-white/40 border border-white/60 rounded-xl py-3 pl-12 pr-4 text-charcoal focus:border-rose-gold/50 focus:bg-white/80 outline-none transition-all placeholder-charcoal/30 shadow-sm font-medium"
                                placeholder="Enter password (any)"
                                required
                            />
                        </div>
                    </div>

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full py-3 bg-gradient-to-r from-aurum to-rose-gold text-white font-bold rounded-xl hover:shadow-soft-glow hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-50 shadow-md"
                    >
                        {loading ? "Connecting..." : "Sign In"}
                    </button>

                    <div className="relative flex items-center gap-4 py-2">
                        <div className="h-[1px] bg-charcoal/10 flex-1" />
                        <span className="text-xs text-charcoal/40 uppercase font-medium">or</span>
                        <div className="h-[1px] bg-charcoal/10 flex-1" />
                    </div>

                    <button
                        type="button"
                        onClick={handleGuest}
                        disabled={loading}
                        className="w-full py-3 bg-white/50 border border-white/60 text-charcoal/70 font-semibold rounded-xl hover:bg-white/80 hover:text-charcoal transition-all disabled:opacity-50 shadow-sm"
                    >
                        Continue as Guest
                    </button>
                </form>
            </motion.div>
        </div>
    );
}
