import React from 'react';
import { createRoot } from 'react-dom/client';
import '@zakisheriff/liquid-glass/styles.css';
import './portal.css';
import { DropitGlassApp } from './DropitGlassApp';

const rootEl = document.getElementById('root');
if (rootEl) {
  const defaultMode = (document.body.dataset.defaultMode as 'send' | 'receive' | undefined) || undefined;
  createRoot(rootEl).render(<DropitGlassApp initialMode={defaultMode} />);
}
