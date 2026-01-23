"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import clsx from "clsx";

const navItems = [
    { name: "Home", href: "/" },
    { name: "Astrology", href: "/astrology" },
    { name: "Tarot", href: "/tarot" },
    { name: "MBTI", href: "/mbti" },
];

export function NavBar() {
    const pathname = usePathname();

    return (
        <nav className="border-b border-white/5 bg-space/70 backdrop-blur-xl sticky top-0 z-50 transition-all duration-300">
            <div className="container mx-auto px-4 h-20 flex items-center justify-between">
                <Link href="/" className="flex items-center gap-3 group">
                    <div className="relative w-10 h-10 rounded-full overflow-hidden border border-rose-gold/20 shadow-glow group-hover:scale-110 transition-transform duration-500">
                        <Image src="/logo.png" alt="OMNI" fill className="object-cover" />
                    </div>
                    <span className="font-display font-bold text-2xl tracking-widest text-transparent bg-clip-text bg-gradient-to-r from-rose-gold to-aurum group-hover:to-starlight transition-all duration-500">
                        OMNI
                    </span>
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
