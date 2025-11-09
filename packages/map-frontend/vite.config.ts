import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { nodePolyfills } from 'vite-plugin-node-polyfills'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    nodePolyfills({
      // Whether to polyfill `node:` protocol imports.
      protocolImports: true,
      // Explicitly include crypto and other Node.js modules
      include: ['crypto', 'stream', 'util', 'buffer', 'process', 'events'],
      // Exclude modules that are not needed
      exclude: [],
      // Globals to polyfill
      globals: {
        Buffer: true,
        global: true,
        process: true,
      },
    }),
  ],
  define: {
    global: 'globalThis',
  },
  resolve: {
    alias: {
      // Ensure crypto is properly polyfilled
      crypto: 'crypto-browserify',
    },
  },
  optimizeDeps: {
    include: ['crypto-browserify'],
  },
})
