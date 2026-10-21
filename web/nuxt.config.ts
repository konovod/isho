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
  app: {
    head: {
      title: 'isho',
      htmlAttrs: { lang: 'ru' },
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
    },
  },
})
