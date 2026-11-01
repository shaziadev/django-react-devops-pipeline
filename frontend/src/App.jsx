import { useEffect, useState } from 'react'
import { createNote, deleteNote, getHealth, getNotes } from './api'

export default function App() {
  const [health, setHealth] = useState(null)
  const [notes, setNotes] = useState([])
  const [title, setTitle] = useState('')
  const [error, setError] = useState('')

  // Load the API status and the notes once when the page opens.
  useEffect(() => {
    getHealth()
      .then(setHealth)
      .catch(() => setHealth({ status: 'error' }))
    getNotes()
      .then(setNotes)
      .catch(() => setError('Could not load notes.'))
  }, [])

  async function handleSubmit(event) {
    event.preventDefault()
    if (!title.trim()) return
    try {
      const note = await createNote({ title })
      setNotes((current) => [note, ...current])
      setTitle('')
      setError('')
    } catch {
      setError('Could not save the note.')
    }
  }

  async function handleDelete(id) {
    await deleteNote(id)
    setNotes((current) => current.filter((note) => note.id !== id))
  }

  const isHealthy = health?.status === 'ok'

  return (
    <main className="container">
      <header className="header">
        <h1>Status Board</h1>
        <span className={`badge ${isHealthy ? 'ok' : 'down'}`} data-testid="health">
          {health === null ? 'Checking API…' : isHealthy ? `API ok · ${health.version}` : 'API unavailable'}
        </span>
      </header>

      <form onSubmit={handleSubmit} className="form">
        <label htmlFor="title" className="sr-only">
          New note
        </label>
        <input
          id="title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g. Deployed v1.2 to staging"
        />
        <button type="submit">Add</button>
      </form>

      {error && <p className="error">{error}</p>}

      <ul className="notes">
        {notes.map((note) => (
          <li key={note.id} className={note.pinned ? 'pinned' : ''}>
            <span>{note.title}</span>
            <button onClick={() => handleDelete(note.id)} aria-label={`Delete ${note.title}`}>
              ×
            </button>
          </li>
        ))}
        {notes.length === 0 && !error && <li className="empty">No notes yet.</li>}
      </ul>
    </main>
  )
}
