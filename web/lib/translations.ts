export type Locale = 'en' | 'zh';

export const translations = {
    en: {
        nav: {
            home: "Home",
            astrology: "Astrology",
            tarot: "Tarot",
            mbti: "MBTI",
            oracle: "Oracle",
            tips: "Tips",
        },
        home: {
            heroTitle: "Omni (万相) — Astrology, Tarot, MBTI, and Oracle AI in one luminous experience.",
            heroDesc: "Enter birth data, draw tarot with realistic shuffling, run professional MBTI Step II assessments, and chat with an always-on Oracle. Built with AI, RAG, and space-grade ephemeris accuracy.",
            launch: "Launch Demo",
            deploy: "Deployment Guide",
            features: {
                astro: "Smart Astrology Engine",
                tarot: "AI Immersive Tarot",
                mbti: "MBTI Step II Facets",
                oracle: "Omni Oracle AI",
                tips: "Tips / Donations",
            }
        },
        astrology: {
            title: "Smart Astrology Engine",
            desc: "Enter your precise birth data to generate a comprehensive natal chart, analyze planetary aspects, and track real-time cosmic transits.",
            form: {
                title: "Birth Data",
                date: "Date of Birth",
                time: "Time of Birth",
                lat: "Latitude",
                long: "Longitude",
                calculate: "Calculate Natal Chart",
                calculating: "Calculating...",
            },
            results: {
                planets: "Planetary Positions",
                aspects: "Major Aspects",
                analysis: "Cosmic Analysis",
                download: "Download Full PDF Report",
                empty: "Chart data will appear here"
            }
        },
        tarot: {
            title: "AI Immersive Tarot",
            desc: "Focus on your question. Let the Fisher-Yates algorithm shuffle the deck, and receive AI-synthesized guidance.",
            questionLabel: "Your Question",
            questionPlaceholder: "What should I focus on this month?",
            selectSpread: "Select Spread",
            spreads: {
                three: "Past / Present / Future",
                celtic: "Celtic Cross",
                decision: "Either / Or Decision"
            },
            draw: "Shuffle & Draw Cards",
            drawing: "Shuffling...",
            interpretation: "Oracle Interpretation"
        },
        mbti: {
            title: "MBTI Step II Assessment",
            desc: "Go beyond the 4 letters. Explore 20 sub-facets to understand the nuance of your personality.",
            start: "Start Assessment",
            analyzing: "Analyzing patterns...",
            question: "Question",
            complete: "Complete",
            midZone: "Mid-Zone Insights",
            profile: "Your Profile"
        },
        oracle: {
            title: "Omni Oracle",
            subtitle: "AI Counselor & Guide",
            placeholder: "Ask anything...",
            roles: {
                mentor: "Rational Mentor",
                healer: "Gentle Healer",
                prophet: "Cold Prophet"
            }
        },
        payments: {
            title: "Tip Omni",
            desc: "Support the cosmic infrastructure. Your contribution keeps the Oracle awake and the Ephemeris spinning.",
            select: "Select Amount",
            custom: "Custom",
            method: "Payment Method",
            send: "Send Tip",
            secure: "Secure Payment Processing",
            thankYou: "Thank You!",
            thankYouDesc: "Your energy exchange has been received. May the stars align for you.",
            again: "Send another tip"
        }
    },
    zh: {
        nav: {
            home: "首页",
            astrology: "占星",
            tarot: "塔罗",
            mbti: "MBTI",
            oracle: "神谕",
            tips: "打赏",
        },
        home: {
            heroTitle: "Omni (万相) — 集占星、塔罗、MBTI 与 AI 神谕于一体的灵性体验。",
            heroDesc: "输入出生信息，使用真实洗牌算法抽取塔罗，进行专业的 MBTI Step II 测评，并与全天候神谕者对话。基于 AI、RAG 和太空级星历精度构建。",
            launch: "启动演示",
            deploy: "部署指南",
            features: {
                astro: "智能占星引擎",
                tarot: "AI 沉浸式塔罗",
                mbti: "MBTI Step II 维度",
                oracle: "Omni 神谕 AI",
                tips: "打赏 / 捐赠",
            }
        },
        astrology: {
            title: "智能占星引擎",
            desc: "输入精准出生信息，生成完整本命盘，分析行星相位，并追踪实时宇宙行运。",
            form: {
                title: "出生信息",
                date: "出生日期",
                time: "出生时间",
                lat: "纬度",
                long: "经度",
                calculate: "计算本命盘",
                calculating: "计算中...",
            },
            results: {
                planets: "行星位置",
                aspects: "主要相位",
                analysis: "宇宙分析",
                download: "下载完整 PDF 报告",
                empty: "星盘数据将显示在这里"
            }
        },
        tarot: {
            title: "AI 沉浸式塔罗",
            desc: "专注于你的问题。让 Fisher-Yates 算法洗牌，并接收 AI 合成的指引。",
            questionLabel: "你的问题",
            questionPlaceholder: "这个月我应该关注什么？",
            selectSpread: "选择牌阵",
            spreads: {
                three: "过去 / 现在 / 未来",
                celtic: "凯尔特十字",
                decision: "二选一决策"
            },
            draw: "洗牌并抽牌",
            drawing: "洗牌中...",
            interpretation: "神谕解读"
        },
        mbti: {
            title: "MBTI Step II 测评",
            desc: "超越这4个字母。探索20个子维度，深入了解你的人格细微之处。",
            start: "开始测评",
            analyzing: "分析模式中...",
            question: "问题",
            complete: "完成",
            midZone: "中间区域洞察",
            profile: "你的画像"
        },
        oracle: {
            title: "Omni 神谕",
            subtitle: "AI 咨询师 & 向导",
            placeholder: "问任何事情...",
            roles: {
                mentor: "理性导师",
                healer: "温柔疗愈师",
                prophet: "冷峻先知"
            }
        },
        payments: {
            title: "打赏 Omni",
            desc: "支持宇宙基础设施。你的贡献让神谕保持清醒，让星历持续运转。",
            select: "选择金额",
            custom: "自定义",
            method: "支付方式",
            send: "发送打赏",
            secure: "安全支付处理",
            thankYou: "谢谢！",
            thankYouDesc: "你的能量交换已收到。愿群星为你对齐。",
            again: "再次打赏"
        }
    }
};
