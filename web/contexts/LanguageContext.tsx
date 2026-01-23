"use client";

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { translations, Locale } from '../lib/translations';

type LanguageContextType = {
    locale: Locale;
    setLocale: (locale: Locale) => void;
    t: typeof translations['en'];
};

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

export function LanguageProvider({ children }: { children: ReactNode }) {
    const [locale, setLocale] = useState<Locale>('en');

    useEffect(() => {
        const saved = localStorage.getItem('omni-locale') as Locale;
        if (saved && (saved === 'en' || saved === 'zh')) {
            setLocale(saved);
        }
    }, []);

    const updateLocale = (newLocale: Locale) => {
        setLocale(newLocale);
        localStorage.setItem('omni-locale', newLocale);
    };

    return (
        <LanguageContext.Provider value={{ locale, setLocale: updateLocale, t: translations[locale] }}>
            {children}
        </LanguageContext.Provider>
    );
}

export function useLanguage() {
    const context = useContext(LanguageContext);
    if (context === undefined) {
        throw new Error('useLanguage must be used within a LanguageProvider');
    }
    return context;
}
