import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
  define: {
    global: 'globalThis',
  },
  resolve: {
    alias: {
      // Polyfill crypto for browser
      crypto: 'crypto-browserify',
      // Polyfill other Node.js modules if needed
      stream: 'stream-browserify',
      buffer: 'buffer',
      util: 'util',
      process: 'process/browser',
    },
  },
  optimizeDeps: {
    include: ['crypto-browserify', 'stream-browserify', 'buffer', 'util', 'process'],
  },
})
