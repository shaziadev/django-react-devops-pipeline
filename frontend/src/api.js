// Small wrapper around fetch. All calls use relative /api URLs:
// Vite proxies them in development and Nginx proxies them in production.

async function request(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`)
  }
  return response.status === 204 ? null : response.json()
}

export const getHealth = () => request('/health/')
export const getNotes = () => request('/notes/').then((data) => data.results)
export const createNote = (note) => request('/notes/', { method: 'POST', body: JSON.stringify(note) })
export const deleteNote = (id) => request(`/notes/${id}/`, { method: 'DELETE' })
