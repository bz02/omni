import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./pages/**/*.{ts,tsx}",
    "./styles/**/*.{ts,tsx,css}"
  ],
  theme: {
    extend: {
      colors: {
        space: "#080510", // Slightly purple-tinted black
        nebula: "#2D004B",
        starlight: "#F8F8FF",
        aurum: "#D4AF37",
        "rose-gold": "#E0BFB8",
        "mystic": "#2E2138",
        "lavender": "#E6E6FA"
      },
      fontFamily: {
        display: ["Inter", "system-ui", "sans-serif"]
      },
      boxShadow: {
        glow: "0 0 30px rgba(212, 175, 55, 0.25)",
        "soft-glow": "0 0 40px rgba(224, 191, 184, 0.2)"
      },
      backgroundImage: {
        'ethereal-gradient': "linear-gradient(to bottom right, #2E2138, #080510)",
      }
    }
  },
  plugins: []
};

export default config;


