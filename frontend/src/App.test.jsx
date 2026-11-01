import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

// Fake API responses keyed by "METHOD path".
function mockFetch(routes) {
  return vi.fn((url, options = {}) => {
    const key = `${options.method || 'GET'} ${url}`
    const body = routes[key]
    return Promise.resolve({
      ok: body !== undefined,
      status: body === undefined ? 500 : 200,
      json: () => Promise.resolve(body),
    })
  })
}

describe('App', () => {
  beforeEach(() => {
    globalThis.fetch = mockFetch({
      'GET /api/health/': { status: 'ok', version: 'abc123' },
      'GET /api/notes/': { results: [{ id: 1, title: 'First deploy', pinned: true }] },
      'POST /api/notes/': { id: 2, title: 'Second deploy', pinned: false },
    })
  })

  afterEach(() => vi.restoreAllMocks())

  it('shows API health and existing notes', async () => {
    render(<App />)

    expect(await screen.findByText('API ok · abc123')).toBeInTheDocument()
    expect(await screen.findByText('First deploy')).toBeInTheDocument()
  })

  it('adds a new note', async () => {
    render(<App />)
    await screen.findByText('First deploy')

    await userEvent.type(screen.getByPlaceholderText(/deployed/i), 'Second deploy')
    await userEvent.click(screen.getByRole('button', { name: 'Add' }))

    expect(await screen.findByText('Second deploy')).toBeInTheDocument()
  })

  it('shows an error badge when the API is down', async () => {
    globalThis.fetch = mockFetch({})
    render(<App />)

    expect(await screen.findByText('API unavailable')).toBeInTheDocument()
  })
})
