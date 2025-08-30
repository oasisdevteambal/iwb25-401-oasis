'use client';

import { useEffect, useRef } from 'react';
import { useChat } from '../context/ChatContext';

/**
 * Clears sessionStorage and chat state when the page is reloaded (hard refresh).
 * Client-side navigations (via next/link) are unaffected.
 */
export default function RefreshResetter() {
    const { clearChat } = useChat();
    const ranRef = useRef(false);

    useEffect(() => {
        if (ranRef.current) return; // guard against double-invoke in React Strict Mode
        ranRef.current = true;

        try {
            const navEntries = window.performance?.getEntriesByType?.('navigation');
            const navType = navEntries && navEntries[0] ? navEntries[0].type : undefined;
            const legacyType = window.performance && window.performance.navigation ? window.performance.navigation.type : undefined;

            const isReload = navType === 'reload' || legacyType === 1;

            if (isReload) {
                // Clear session storage for the whole tab session
                try {
                    sessionStorage.clear();
                } catch (_) {
                    // ignore
                }
                // Clear chat state in memory/UI
                clearChat();
            }
        } catch (_) {
            // ignore
        }
    }, [clearChat]);

    return null;
}
