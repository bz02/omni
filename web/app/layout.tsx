import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Omni | New-Age Digital Mysticism",
  description: "Astrology, Tarot, MBTI, and AI Oracle unified in one experience."
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-space text-starlight">
        <div className="min-h-screen">
          <header className="border-b border-neutral-800/70 bg-black/40 backdrop-blur-lg sticky top-0 z-20">
            <div className="mx-auto max-w-6xl px-4 py-4 flex items-center justify-between">
              <div className="font-bold tracking-tight text-xl text-aurum">Omni (万相)</div>
              <nav className="flex gap-4 text-sm">
                <a href="#astrology" className="hover:text-aurum">Astrology</a>
                <a href="#tarot" className="hover:text-aurum">Tarot</a>
                <a href="#mbti" className="hover:text-aurum">Personality</a>
                <a href="#oracle" className="hover:text-aurum">Oracle AI</a>
                <a href="#payments" className="hover:text-aurum">Tips</a>
              </nav>
            </div>
          </header>
          <main className="mx-auto max-w-6xl px-4 py-10 space-y-12">{children}</main>
          <footer className="border-t border-neutral-800/70 bg-black/40 backdrop-blur-lg">
            <div className="mx-auto max-w-6xl px-4 py-6 text-sm text-neutral-400 flex justify-between">
              <span>© 2026 Omni. Built for New-Age Digital Mysticism.</span>
              <a className="hover:text-aurum" href="#compliance">Privacy & Compliance</a>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}

