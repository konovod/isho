import { SITE_NAME } from './app/utils/site'

export default defineNuxtConfig({
  compatibilityDate: '2026-10-01',
  devtools: { enabled: false },
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    // Used by SSR only. Set NUXT_API_INTERNAL_BASE in production.
    apiInternalBase: 'http://127.0.0.1:4000',
    public: {
      apiBase: '',
    },
  },
  nitro: {
    devProxy: {
      '/api': { target: 'http://127.0.0.1:4000/api', changeOrigin: true },
      '/media': { target: 'http://127.0.0.1:4000/media', changeOrigin: true },
    },
  },
  vite: {
    optimizeDeps: {
      // Pre-bundle the Markdown renderer so dev does not reload on first use.
      include: [
        'markdown-it',
        'markdown-it-container',
        'highlight.js/lib/core',
        'highlight.js/lib/languages/bash',
        'highlight.js/lib/languages/c',
        'highlight.js/lib/languages/cpp',
        'highlight.js/lib/languages/crystal',
        'highlight.js/lib/languages/csharp',
        'highlight.js/lib/languages/css',
        'highlight.js/lib/languages/diff',
        'highlight.js/lib/languages/go',
        'highlight.js/lib/languages/ini',
        'highlight.js/lib/languages/java',
        'highlight.js/lib/languages/javascript',
        'highlight.js/lib/languages/json',
        'highlight.js/lib/languages/kotlin',
        'highlight.js/lib/languages/lua',
        'highlight.js/lib/languages/markdown',
        'highlight.js/lib/languages/php',
        'highlight.js/lib/languages/plaintext',
        'highlight.js/lib/languages/powershell',
        'highlight.js/lib/languages/python',
        'highlight.js/lib/languages/ruby',
        'highlight.js/lib/languages/rust',
        'highlight.js/lib/languages/sql',
        'highlight.js/lib/languages/typescript',
        'highlight.js/lib/languages/xml',
        'highlight.js/lib/languages/yaml',
      ],
    },
  },
  app: {
    head: {
      title: SITE_NAME,
      htmlAttrs: { lang: 'ru' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
    },
  },
})
