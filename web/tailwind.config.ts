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
        space: "#FAFAFA", // Now Cream/White
        nebula: "#F0E6FA", // Light Lavender
        starlight: "#2E2138", // Dark text (formerly light)
        aurum: "#D48C70", // Soft Coral/Bronze (replacing yellow/gold)
        "rose-gold": "#E0BFB8",
        "mystic": "#FFFFFF", // White for cards
        "lavender": "#9F90D0", // Deeper lavender for accents
        "charcoal": "#2E2138", // Explicit dark text
      },
      fontFamily: {
        display: ["Inter", "system-ui", "sans-serif"]
      },
      boxShadow: {
        glow: "0 4px 20px rgba(212, 140, 112, 0.15)",
        "soft-glow": "0 4px 30px rgba(224, 191, 184, 0.25)"
      },
      backgroundImage: {
        'ethereal-gradient': "linear-gradient(to bottom right, #FFF5F5, #F0E6FA)",
      }
    }
  },
  plugins: []
};

export default config;


