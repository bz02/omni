import { Brain, Compass, HandCoins, MessageSquare, MoonStar } from "lucide-react";
import Image from "next/image";

const quickFeatures = [
  { title: "Smart Astrology Engine", body: "Precise natal charts with house systems, aspects, synastry, and live transit alerts.", icon: <MoonStar className="text-aurum" /> },
  { title: "AI Immersive Tarot", body: "Fisher–Yates shuffle, 3D flips, multiple spreads, and AI that fuses tarot with your natal profile.", icon: <Compass className="text-aurum" /> },
  { title: "MBTI Step II Facets", body: "90–144 item assessment with mid-zones, evolution curves, and collaboration comparisons.", icon: <Brain className="text-aurum" /> },
  { title: "Omni Oracle AI", body: "Voice + text, multiple personas, memory of life events, and daily visual fortune cards.", icon: <MessageSquare className="text-aurum" /> },
  { title: "Tips / Donations", body: "Secure card payments with receipts, history, admin reports, and dispute flows.", icon: <HandCoins className="text-aurum" /> }
];

const tarotSpreads = [
  "Past–Present–Future (3-card)",
  "Celtic Cross (10-card)",
  "Either-Or Decision Spread",
  "Relationship (Synastry) Spread"
];

const mbtiFacets = [
  "Initiating / Receiving",
  "Expressive / Contained",
  "Gregarious / Intimate",
  "Active / Reflective",
  "Enthusiastic / Quiet",
  "Concrete / Abstract",
  "Realistic / Imaginative",
  "Practical / Conceptual",
  "Experiential / Theoretical",
  "Traditional / Original",
  "Logical / Empathetic",
  "Reasonable / Compassionate",
  "Questioning / Accommodating",
  "Critical / Accepting",
  "Tough / Tender",
  "Systematic / Casual",
  "Planful / Open-Ended",
  "Early-Starting / Pressure-Prompted",
  "Scheduled / Spontaneous",
  "Methodical / Emergent"
];

const personas = [
  { name: "Rational Mentor", tone: "Logic-driven, practical recommendations." },
  { name: "Gentle Healer", tone: "Soothing, emotionally supportive." },
  { name: "Cold Prophet", tone: "Objective, sharp, tough-love like Co–Star." }
];

export default function Home() {
  return (
    <div className="space-y-12">
      <section className="grid gap-10 lg:grid-cols-2 items-center">
        <div className="space-y-6">
          <p className="section-title">New-Age Digital Mysticism</p>
          <h1 className="text-4xl md:text-5xl font-semibold leading-tight">Omni (万相) — Astrology, Tarot, MBTI, and Oracle AI in one luminous experience.</h1>
          <p className="text-neutral-300 leading-relaxed">
            Enter birth data, draw tarot with realistic shuffling, run professional MBTI Step II assessments, and chat with an always-on Oracle. Built with AI, RAG, and space-grade ephemeris accuracy.
          </p>
          <div className="flex gap-3">
            <a className="px-4 py-2 rounded-full bg-aurum text-black font-semibold shadow-glow" href="#demo">Launch Demo</a>
            <a className="px-4 py-2 rounded-full border border-aurum/60 text-aurum" href="#deployment">Deployment Guide</a>
          </div>
          <div className="flex gap-2 text-xs uppercase tracking-[0.2em] text-neutral-400">
            <span>Gemini 3.0</span>
            <span>OpenAI GPT</span>
            <span>Pinecone</span>
            <span>Swiss Ephemeris</span>
          </div>
        </div>
        <div className="relative h-80 rounded-3xl overflow-hidden border border-neutral-800 shadow-glow">
          <Image src="https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?auto=format&fit=crop&w=1200&q=80" alt="Cosmic UI" fill className="object-cover opacity-70" />
          <div className="absolute inset-0 bg-gradient-to-br from-black via-neutral-900/70 to-transparent" />
          <div className="absolute bottom-4 left-4 right-4 card">
            <div className="text-sm text-neutral-300">Live Transit Alert</div>
            <div className="text-lg font-semibold">Saturn return approaching: integrate lessons, reinforce boundaries.</div>
          </div>
        </div>
      </section>

      <section id="astrology" className="space-y-6">
        <p className="section-title">Smart Astrology Engine</p>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="card col-span-2 space-y-4">
            <h2 className="text-2xl font-semibold">Natal charts, aspects, transits, synastry</h2>
            <p className="text-neutral-300">Supports 10+ bodies, AC/MC, Chiron, multiple house systems, and rich aspect logic (conjunction, square, opposition, trine, sextile). Real-time transit tracker compares now vs. natal and pushes alerts.</p>
            <div className="flex gap-3 text-sm text-neutral-400 flex-wrap">
              <span className="px-3 py-1 rounded-full border border-neutral-700">Swiss Ephemeris</span>
              <span className="px-3 py-1 rounded-full border border-neutral-700">NASA JPL</span>
              <span className="px-3 py-1 rounded-full border border-neutral-700">Push alerts</span>
              <span className="px-3 py-1 rounded-full border border-neutral-700">Relationship charts</span>
            </div>
            <div className="flex gap-3 text-sm">
              <input className="flex-1 bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="Birth data input (YYYY-MM-DD HH:mm, lat/long)" />
              <button className="px-4 py-2 rounded-lg bg-aurum text-black font-semibold">Generate</button>
            </div>
          </div>
          <div className="card space-y-3">
            <h3 className="text-lg font-semibold">Transit Watchlist</h3>
            <div className="space-y-2 text-sm text-neutral-300">
              <div>• Mercury retrograde: suggest reflection, backup data.</div>
              <div>• Mars square Moon: emotional triggers — propose grounding.</div>
              <div>• Venus trine Jupiter: amplify social and financial flow.</div>
            </div>
          </div>
        </div>
      </section>

      <section id="tarot" className="space-y-6">
        <p className="section-title">AI Immersive Tarot</p>
        <div className="grid md:grid-cols-2 gap-6">
          <div className="card space-y-4">
            <h2 className="text-2xl font-semibold">Fisher–Yates shuffle + 3D flip visuals</h2>
            <p className="text-neutral-300">Pick a spread, enter your question, and draw. AI combines upright/reversed meanings with your astrology profile for contextual guidance.</p>
            <div className="space-y-2">
              <label className="text-sm text-neutral-400">Your question</label>
              <input className="w-full bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="What should I focus on this quarter?" />
            </div>
            <div className="flex gap-3 text-sm flex-wrap">
              {tarotSpreads.map((item) => (
                <span key={item} className="px-3 py-1 rounded-full border border-neutral-700">{item}</span>
              ))}
            </div>
            <button className="px-4 py-2 rounded-lg bg-aurum text-black font-semibold w-full">Shuffle & Draw</button>
          </div>
          <div className="card space-y-3">
            <h3 className="text-lg font-semibold">AI Interpretation (sample)</h3>
            <div className="text-sm text-neutral-300 space-y-2">
              <div>• Past: The Chariot (upright) — momentum came from decisive moves.</div>
              <div>• Present: The Moon (reversed) — surface fears; clarify signals vs. noise.</div>
              <div>• Future: The Star (upright) — align with purpose; share your vision.</div>
              <div className="text-aurum font-semibold">Action: Pair your Moon trine Venus transit with grounding rituals; schedule feedback loops.</div>
            </div>
          </div>
        </div>
      </section>

      <section id="mbti" className="space-y-6">
        <p className="section-title">MBTI Step II Facets</p>
        <div className="grid md:grid-cols-2 gap-6">
          <div className="card space-y-3">
            <h2 className="text-2xl font-semibold">Facet-level depth + evolution</h2>
            <p className="text-neutral-300">90–144 item assessment with mid-zone interpretations. Retake every 6 months to visualize evolution curves.</p>
            <div className="grid grid-cols-2 gap-2 text-sm text-neutral-300">
              {mbtiFacets.map((facet) => (
                <div key={facet} className="px-3 py-2 rounded-lg bg-neutral-900/70 border border-neutral-800">{facet}</div>
              ))}
            </div>
          </div>
          <div className="card space-y-3">
            <h3 className="text-lg font-semibold">Comparison + Conflict Resolution</h3>
            <p className="text-neutral-300">Compare partners/teams and let AI propose conflict-resolution tactics using temperament and facet gaps.</p>
            <div className="flex gap-3">
              <input className="flex-1 bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="Upload or paste Partner A results" />
              <input className="flex-1 bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="Partner B results" />
            </div>
            <div className="text-sm text-neutral-300">Tip: Align high “Questioning” with “Accepting” by pre-agreeing on debate windows, then switching to decision mode.</div>
          </div>
        </div>
      </section>

      <section id="oracle" className="space-y-6">
        <p className="section-title">Omni Oracle AI</p>
        <div className="card space-y-4">
          <div className="grid md:grid-cols-3 gap-4">
            {personas.map((persona) => (
              <div key={persona.name} className="bg-neutral-900/70 border border-neutral-800 rounded-xl p-4">
                <div className="font-semibold text-aurum">{persona.name}</div>
                <div className="text-sm text-neutral-300">{persona.tone}</div>
              </div>
            ))}
          </div>
          <div className="flex items-center gap-3">
            <input className="flex-1 bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="Ask anything — relationship, career, spiritual guidance" />
            <button className="px-4 py-2 rounded-lg bg-aurum text-black font-semibold">Ask Oracle</button>
          </div>
          <div className="text-sm text-neutral-300">Memory: keeps consultation history + life events for coherent, long-horizon guidance. Daily visual fortune cards generated with DALL·E.</div>
        </div>
      </section>

      <section id="payments" className="space-y-6">
        <p className="section-title">Tips / Donations</p>
        <div className="card space-y-3">
          <h2 className="text-2xl font-semibold">Tip the Reader / Tip Omni</h2>
          <p className="text-neutral-300">Custom amounts + quick picks. Secure processing, receipts, history, refunds via provider standards.</p>
          <div className="flex gap-3">
            <input className="flex-1 bg-neutral-900 border border-neutral-800 rounded-lg px-3 py-2" placeholder="Enter amount (e.g., 18.88)" />
            <button className="px-4 py-2 rounded-lg bg-aurum text-black font-semibold">Tip Now</button>
          </div>
          <div className="flex gap-2 text-sm text-neutral-400">
            <span className="px-3 py-1 rounded-full border border-neutral-700">$5</span>
            <span className="px-3 py-1 rounded-full border border-neutral-700">$11.11</span>
            <span className="px-3 py-1 rounded-full border border-neutral-700">$33.33</span>
            <span className="px-3 py-1 rounded-full border border-neutral-700">Custom</span>
          </div>
          <div className="text-sm text-neutral-300">Receipts + history surface under your profile. Admin console exports payouts and disputes.</div>
        </div>
      </section>

      <section id="compliance" className="space-y-4">
        <p className="section-title">Privacy & Compliance</p>
        <div className="card space-y-3 text-sm text-neutral-300">
          <div>• Data de-identification before LLM calls (strip names/phones). </div>
          <div>• PIPL alignment: explicit consent before geolocation/SDK access; first-launch disclosures.</div>
          <div>• Transparency label: list all collected data types + purposes.</div>
          <div>• Secrets in env vars; encryption in transit/at rest.</div>
        </div>
      </section>

      <section id="deployment" className="space-y-4">
        <p className="section-title">Deployment Overview</p>
        <div className="card space-y-3 text-sm text-neutral-300">
          <div><strong>Frontend:</strong> Next.js static/SSR on Vercel or AWS Amplify. </div>
          <div><strong>Backend:</strong> Node.js gateway (API + WebSocket) + Python worker for ephemeris + RAG. Containerize via Docker; deploy to AWS ECS Fargate or GCP Cloud Run.</div>
          <div><strong>Data:</strong> PostgreSQL (RDS/Cloud SQL) + Pinecone (vector) + S3/GCS for assets.</div>
          <div><strong>Payments:</strong> Stripe with webhooks for tips; secure secrets via AWS Secrets Manager/SSM.</div>
        </div>
      </section>

      <section id="demo" className="space-y-4">
        <p className="section-title">API Stubs (to wire)</p>
        <div className="card space-y-2 text-sm text-neutral-300">
          <div>GET /api/astrology?birth=... → returns chart + aspects + transits</div>
          <div>POST /api/tarot/draw → {`{spread, cards: [name, orientation], aiSummary}`}</div>
          <div>POST /api/mbti/submit → scores facets, returns type + mid-zones</div>
          <div>POST /api/oracle → persona + text/voice; returns streaming answer</div>
          <div>POST /api/payments/tip → creates Stripe PaymentIntent; webhook handles confirmation</div>
        </div>
      </section>
    </div>
  );
}

