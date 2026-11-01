import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// In development, Vite forwards /api calls to Django so the browser sees one origin
// (the same way Nginx does in production).
const apiTarget = process.env.VITE_API_PROXY || 'http://localhost:8000'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    proxy: { '/api': apiTarget },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/setupTests.js',
  },
})
