import React from 'react';
import '@zakisheriff/liquid-glass/styles.css';
import '../src/portal.css';

export const metadata = {
  title: 'Dropit — Liquid Glass Browser Sharing Portal',
  description: 'Peer-to-peer local Wi-Fi file sharing with Apple-style Liquid Glass UI.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
