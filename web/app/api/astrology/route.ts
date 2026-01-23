import { NextResponse } from 'next/server';

// Keep GET for simple health check/stub if needed
export async function GET() {
  return NextResponse.json({ status: "Astrology Engine Online" });
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { date, time, lat, long, locale } = body;
    const isZh = locale === 'zh';

    // Mock calculation
    const mockChart = {
      planets: [
        { name: isZh ? '太阳' : 'Sun', sign: isZh ? '狮子座' : 'Leo', degree: 14.2, house: 5 },
        { name: isZh ? '月亮' : 'Moon', sign: isZh ? '天蝎座' : 'Scorpio', degree: 2.5, house: 8 },
        { name: isZh ? '水星' : 'Mercury', sign: isZh ? '处女座' : 'Virgo', degree: 22.1, house: 6 },
        { name: isZh ? '金星' : 'Venus', sign: isZh ? '天秤座' : 'Libra', degree: 5.8, house: 7 },
        { name: isZh ? '火星' : 'Mars', sign: isZh ? '白羊座' : 'Aries', degree: 10.3, house: 1 },
        { name: isZh ? '木星' : 'Jupiter', sign: isZh ? '双鱼座' : 'Pisces', degree: 28.4, house: 12 },
        { name: isZh ? '土星' : 'Saturn', sign: isZh ? '水瓶座' : 'Aquarius', degree: 15.6, house: 11 },
        { name: isZh ? '天王星' : 'Uranus', sign: isZh ? '金牛座' : 'Taurus', degree: 9.2, house: 2 },
        { name: isZh ? '海王星' : 'Neptune', sign: isZh ? '双鱼座' : 'Pisces', degree: 24.5, house: 12 },
        { name: isZh ? '冥王星' : 'Pluto', sign: isZh ? '摩羯座' : 'Capricorn', degree: 26.8, house: 10 },
        { name: isZh ? '上升' : 'Ascendant', sign: isZh ? '白羊座' : 'Aries', degree: 12.0, house: 1 },
        { name: isZh ? '中天' : 'Midheaven', sign: isZh ? '摩羯座' : 'Capricorn', degree: 5.0, house: 10 },
      ],
      aspects: [
        { planet1: isZh ? '太阳' : 'Sun', planet2: isZh ? '火星' : 'Mars', type: isZh ? '三分相' : 'Trine', angle: 120, orb: 3.9 },
        { planet1: isZh ? '月亮' : 'Moon', planet2: isZh ? '金星' : 'Venus', type: isZh ? '合相' : 'Conjunction', angle: 0, orb: 3.3 },
        { planet1: isZh ? '水星' : 'Mercury', planet2: isZh ? '土星' : 'Saturn', type: isZh ? '对分相' : 'Opposition', angle: 180, orb: 6.5 },
        { planet1: isZh ? '金星' : 'Venus', planet2: isZh ? '冥王星' : 'Pluto', type: isZh ? '四分相' : 'Square', angle: 90, orb: 1.0 },
      ],
      analysis: isZh
        ? `基于您的出生数据（${date} ${time}），您的星盘显示太阳位于狮子座，表明您有强烈的自我表达欲望和创造力。
        
        月亮位于天蝎座暗示了深层的情感和转化潜力。
        
        太阳与火星的三分相为启动项目提供了极佳的能量，而水星与土星的对分相则提醒您在沟通时要倍加小心。`
        : `Based on your birth data (${date} at ${time}), your chart reveals a powerful Sun in Leo, indicating a strong drive for self-expression and creativity. 
      
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
