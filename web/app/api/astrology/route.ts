import { NextResponse } from 'next/server';

// Keep GET for simple health check/stub if needed
export async function GET() {
  return NextResponse.json({ status: "Astrology Engine Online" });
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { date, time, lat, long } = body;

    // Mock calculation - normally this would call Python/C++ Swiss Ephemeris
    // Returning a realistic looking payload for the frontend to render
    const mockChart = {
      planets: [
        { name: 'Sun', sign: 'Leo', degree: 14.2, house: 5 },
        { name: 'Moon', sign: 'Scorpio', degree: 2.5, house: 8 },
        { name: 'Mercury', sign: 'Virgo', degree: 22.1, house: 6 },
        { name: 'Venus', sign: 'Libra', degree: 5.8, house: 7 },
        { name: 'Mars', sign: 'Aries', degree: 10.3, house: 1 },
        { name: 'Jupiter', sign: 'Pisces', degree: 28.4, house: 12 },
        { name: 'Saturn', sign: 'Aquarius', degree: 15.6, house: 11 },
        { name: 'Uranus', sign: 'Taurus', degree: 9.2, house: 2 },
        { name: 'Neptune', sign: 'Pisces', degree: 24.5, house: 12 },
        { name: 'Pluto', sign: 'Capricorn', degree: 26.8, house: 10 },
        { name: 'Ascendant', sign: 'Aries', degree: 12.0, house: 1 },
        { name: 'Midheaven', sign: 'Capricorn', degree: 5.0, house: 10 },
      ],
      aspects: [
        { planet1: 'Sun', planet2: 'Mars', type: 'Trine', angle: 120, orb: 3.9 },
        { planet1: 'Moon', planet2: 'Venus', type: 'Conjunction', angle: 0, orb: 3.3 },
        { planet1: 'Mercury', planet2: 'Saturn', type: 'Opposition', angle: 180, orb: 6.5 },
        { planet1: 'Venus', planet2: 'Pluto', type: 'Square', angle: 90, orb: 1.0 },
      ],
      analysis: `Based on your birth data (${date} at ${time}), your chart reveals a powerful Sun in Leo, indicating a strong drive for self-expression and creativity. 
      
      The Moon in Scorpio suggests deep emotions and transformative potential. 
      
      A trine between the Sun and Mars provides excellent energy for initiating projects, while the Mercury-Saturn opposition cautions you to double-check your communications.`
    };

    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 800));

    return NextResponse.json(mockChart);
  } catch (e) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}
