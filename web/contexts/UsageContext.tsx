"use client";

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';

type UsageContextType = {
    chatCount: number;
    featureCount: number;
    incrementChat: () => boolean; // Returns true if allowed, false if limit reached
    incrementFeature: () => boolean; // Returns true if allowed, false if limit reached
    hasAccess: boolean;
    unlockPro: () => void;
    showPaywall: boolean;
    openPaywall: () => void;
    closePaywall: () => void;
};

const UsageContext = createContext<UsageContextType | undefined>(undefined);

const CHAT_LIMIT = 3;
const FEATURE_LIMIT = 3;

export function UsageProvider({ children }: { children: ReactNode }) {
    const [chatCount, setChatCount] = useState(0);
    const [featureCount, setFeatureCount] = useState(0);
    const [hasAccess, setHasAccess] = useState(false);
    const [showPaywall, setShowPaywall] = useState(false);

    // Load from localStorage on mount
    useEffect(() => {
        const savedChat = localStorage.getItem('omni-usage-chat-v2');
        const savedFeature = localStorage.getItem('omni-usage-feature-v2');
        const savedAccess = localStorage.getItem('omni-pro-access-v2');

        if (savedChat) setChatCount(parseInt(savedChat));
        if (savedFeature) setFeatureCount(parseInt(savedFeature));
        if (savedAccess === 'true') setHasAccess(true);
    }, []);

    const incrementChat = () => {
        if (hasAccess) return true;
        if (chatCount >= CHAT_LIMIT) {
            setShowPaywall(true);
            return false;
        }

        const newCount = chatCount + 1;
        setChatCount(newCount);
        localStorage.setItem('omni-usage-chat-v2', newCount.toString());
        return true;
    };

    const incrementFeature = () => {
        if (hasAccess) return true;
        if (featureCount >= FEATURE_LIMIT) {
            setShowPaywall(true);
            return false;
        }

        const newCount = featureCount + 1;
        setFeatureCount(newCount);
        localStorage.setItem('omni-usage-feature-v2', newCount.toString());
        return true;
    };

    const unlockPro = () => {
        setHasAccess(true);
        localStorage.setItem('omni-pro-access-v2', 'true');
        setShowPaywall(false);
    };

    return (
        <UsageContext.Provider value={{
            chatCount,
            featureCount,
            incrementChat,
            incrementFeature,
            hasAccess,
            unlockPro,
            showPaywall,
            openPaywall: () => setShowPaywall(true),
            closePaywall: () => setShowPaywall(false)
        }}>
            {children}
        </UsageContext.Provider>
    );
}

export function useUsage() {
    const context = useContext(UsageContext);
    if (context === undefined) {
        throw new Error('useUsage must be used within a UsageProvider');
    }
    return context;
}
