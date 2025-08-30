'use client';

import { usePathname } from 'next/navigation';
import FloatingChatbot from './FloatingChatbot';

export default function ConditionalFloatingChatbot() {
    const pathname = usePathname();

    // Don't show the floating chatbot on admin pages or the dedicated chat page
    const isAdminPage = pathname?.startsWith('/admin');
    const isChatPage = pathname === '/chat';

    // Show the floating chatbot on all pages except admin and dedicated chat page
    if (isAdminPage || isChatPage) {
        return null;
    }

    return <FloatingChatbot />;
}
