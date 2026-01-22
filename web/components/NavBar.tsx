"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import clsx from "clsx";
import { Sparkles } from "lucide-react";

const navItems = [
    { name: "Home", href: "/" },
    { name: "Astrology", href: "/astrology" },
    { name: "Tarot", href: "/tarot" },
    { name: "MBTI", href: "/mbti" },
    { name: "Oracle", href: "/oracle" },
];

export function NavBar() {
    const pathname = usePathname();

    return (
        <nav className="border-b border-neutral-800 bg-black/50 backdrop-blur-md sticky top-0 z-50">
            <div className="container mx-auto px-4 h-16 flex items-center justify-between">
                <Link href="/" className="flex items-center gap-2 font-bold text-xl text-aurum tracking-wider">
                    <Sparkles className="w-5 h-5" />
                    OMNI
                </Link>

                <div className="flex items-center gap-6">
                    {navItems.map((item) => (
                        <Link
                            key={item.href}
                            href={item.href}
                            className={clsx(
                                "text-sm font-medium transition-colors hover:text-aurum",
                                pathname === item.href ? "text-aurum" : "text-neutral-400"
                            )}
                        >
                            {item.name}
                        </Link>
                    ))}
                </div>
            </div>
        </nav>
    );
}
