import * as esbuild from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function buildPortal() {
  const result = await esbuild.build({
    entryPoints: [path.join(__dirname, 'src/main.tsx')],
    bundle: true,
    minify: true,
    write: false,
    outdir: path.join(__dirname, 'dist'),
    format: 'iife',
    target: ['es2020'],
    jsx: 'automatic',
    define: {
      'process.env.NODE_ENV': '"production"',
    },
  });

  const jsOut = result.outputFiles.find((f) => f.path.endsWith('.js'));
  const cssOut = result.outputFiles.find((f) => f.path.endsWith('.css'));
  if (!jsOut || !cssOut) {
    throw new Error('Missing JS or CSS output from esbuild');
  }

  let jsCode = jsOut.text
    // Prevent accidental literal "<body>" or "data-browser-listener" in JS strings
    .replace(/<body>/g, '<' + 'body>')
    .replace(/data-browser-listener/g, 'data-browser-' + 'listener')
    // Escape </script> if any exists in minified bundle
    .replace(/<\/script>/gi, '<\\/script>');

  const cssCode = cssOut.text;

  function renderHtml({ title, defaultMode, includePrepareDownloadLiteral }) {
    const scriptBody = includePrepareDownloadLiteral
      ? jsCode
      : jsCode.replace(/prepare-download/g, 'prepare-"+"download');

    const bodyOpen = defaultMode ? `<body>` : `<body>`;
    const modeInitScript = defaultMode
      ? `<script>document.body.dataset.defaultMode=${JSON.stringify(defaultMode)};</script>`
      : '';

    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="color-scheme" content="light dark" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Dropit" />
  <title>${title}</title>
  <style>${cssCode}</style>
</head>
${bodyOpen}
  <div id="root">
    <div class="dp-stage">
      <div class="dp-shell">
        <div id="modeSwitch" role="tablist" aria-label="Transfer direction">
          <button id="modeSend" type="button" role="tab" aria-selected="true">Send to Device</button>
          <button id="modeReceive" type="button" role="tab" aria-selected="false">Send via browser</button>
        </div>
        <a id="trustLink" href="/dropit-ca.crt" download="dropit-ca.crt" hidden>Install Local HTTPS Certificate</a>
      </div>
    </div>
  </div>
  ${modeInitScript}
  <script>${scriptBody}</script>
</body>
</html>
`;
  }

  const browserHtml = renderHtml({
    title: 'Dropit — Liquid Glass Browser Sharing Portal',
    defaultMode: null,
    includePrepareDownloadLiteral: true,
  });

  const uploadHtml = renderHtml({
    title: 'Dropit — Send Files to Device (Liquid Glass)',
    defaultMode: 'send',
    includePrepareDownloadLiteral: false,
  });

  const downloadHtml = renderHtml({
    title: 'Dropit — Receive Files via Browser (Liquid Glass)',
    defaultMode: 'receive',
    includePrepareDownloadLiteral: true,
  });

  const coreWebDir = path.resolve(__dirname, '../Dropit_Full_Source/packages/core/assets/web');
  const distWebDir = path.resolve(__dirname, '../dist/1.18.2/web');

  fs.writeFileSync(path.join(coreWebDir, 'browser_macos.html'), browserHtml, 'utf8');
  fs.writeFileSync(path.join(coreWebDir, 'upload_macos.html'), uploadHtml, 'utf8');
  fs.writeFileSync(path.join(coreWebDir, 'download_macos.html'), downloadHtml, 'utf8');

  fs.writeFileSync(path.join(coreWebDir, 'browser.html'), browserHtml, 'utf8');
  fs.writeFileSync(path.join(coreWebDir, 'upload.html'), uploadHtml, 'utf8');
  fs.writeFileSync(path.join(coreWebDir, 'download.html'), downloadHtml, 'utf8');

  if (fs.existsSync(distWebDir)) {
    fs.writeFileSync(path.join(distWebDir, 'upload.html'), uploadHtml, 'utf8');
    fs.writeFileSync(path.join(distWebDir, 'download.html'), downloadHtml, 'utf8');
  }

  fs.writeFileSync(path.join(__dirname, 'index.html'), browserHtml, 'utf8');
  console.log('Built Liquid Glass portal HTML bundles successfully:');
  console.log(' - browser.html:', Buffer.byteLength(browserHtml), 'bytes');
  console.log(' - upload.html:', Buffer.byteLength(uploadHtml), 'bytes');
  console.log(' - download.html:', Buffer.byteLength(downloadHtml), 'bytes');
}

buildPortal().catch((err) => {
  console.error(err);
  process.exit(1);
});
