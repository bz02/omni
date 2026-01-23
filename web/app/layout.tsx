import "../styles/globals.css";
import { NavBar } from "../components/NavBar";
import { LanguageProvider } from "../contexts/LanguageContext";
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
        <LanguageProvider>
          <div className="min-h-screen">
            <NavBar />
            <main className="mx-auto max-w-6xl px-4 py-10 space-y-12">{children}</main>
            <footer className="border-t border-neutral-800/70 bg-black/40 backdrop-blur-lg">
              <div className="mx-auto max-w-6xl px-4 py-6 text-sm text-neutral-400 flex justify-between">
                <span>© 2026 Omni. Built for New-Age Digital Mysticism.</span>
                <a className="hover:text-aurum" href="#compliance">Privacy & Compliance</a>
              </div>
            </footer>
          </div>
        </LanguageProvider>
      </body>
    </html>
  );
}

