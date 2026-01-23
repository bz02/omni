
"use client";

import { signIn, signOut, useSession } from "next-auth/react";
import { LogIn, LogOut, User } from "lucide-react";
import { useLanguage } from "../contexts/LanguageContext";

export default function LoginButton() {
    const { data: session } = useSession();
    const { t } = useLanguage();

    if (session) {
        return (
            <div className="flex items-center gap-4">
                <div className="flex items-center gap-2 text-sm text-charcoal/80 font-medium">
                    <User className="w-4 h-4" />
                    <span>{session.user?.name}</span>
                </div>
                <button
                    onClick={() => signOut()}
                    className="flex items-center gap-2 px-4 py-2 bg-white/50 border border-rose-gold/20 rounded-full hover:bg-white/80 hover:border-aurum/30 transition-all text-sm font-medium text-charcoal"
                >
                    <LogOut className="w-4 h-4" />
                    <span className="hidden md:inline">Sign Out</span>
                </button>
            </div>
        );
    }

    return (
        <button
            onClick={() => signIn()}
            className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-aurum to-rose-gold text-white font-bold rounded-full hover:shadow-soft-glow hover:scale-105 transition-all text-sm shadow-md"
        >
            <LogIn className="w-4 h-4" />
            <span className="hidden md:inline">Login / Guest</span>
        </button>
    );
}
