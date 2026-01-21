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
        space: "#0A0A0A",
        nebula: "#2D004B",
        starlight: "#F8F8FF",
        aurum: "#D4AF37"
      },
      fontFamily: {
        display: ["Inter", "system-ui", "sans-serif"]
      },
      boxShadow: {
        glow: "0 0 30px rgba(212, 175, 55, 0.35)"
      }
    }
  },
  plugins: []
};

export default config;

