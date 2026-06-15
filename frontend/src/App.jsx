import { useState } from 'react'
import './App.css'

const API_URL = import.meta.env.VITE_API_URL || 'https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/summarize'

async function fetchWithRetry(url, options, retries = 2) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options)
      const data = await response.json()

      // Don't retry client errors (400, 422) — only server errors (5xx)
      if (response.ok || response.status < 500) {
        return data
      }

      if (attempt === retries) {
        throw new Error(data.error || 'Server error. Please try again later.')
      }
    } catch (err) {
      if (attempt === retries) {
        throw new Error(err.message || 'Failed to connect to the API. Please try again.')
      }
    }

    // Wait before retrying: 1s, then 2s
    await new Promise((r) => setTimeout(r, (attempt + 1) * 1000))
  }
}

function App() {
  const [inputText, setInputText] = useState('')
  const [result, setResult] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setResult(null)
    setError(null)

    if (!inputText.trim()) {
      setError('Please enter some text to summarize.')
      return
    }

    if (inputText.length > 10000) {
      setError('Text exceeds maximum length of 10,000 characters.')
      return
    }

    setLoading(true)

    try {
      const data = await fetchWithRetry(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: inputText.trim() }),
      })

      setResult(data)
    } catch (err) {
      setError(err.message || 'Failed to connect to the API. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleClear = () => {
    setInputText('')
    setResult(null)
    setError(null)
  }

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <h1>🛡️ AI Content Guard</h1>
          <p className="subtitle">AI-powered text summarizer with content safety guardrails</p>
        </div>
      </header>

      <main className="main">
        <form onSubmit={handleSubmit} className="form">
          <label htmlFor="input-text" className="label">
            Enter text to summarize
            <span className="char-count">{inputText.length} / 10,000</span>
          </label>
          <textarea
            id="input-text"
            className="textarea"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            placeholder="Paste or type your text here... The AI will summarize it in 2-3 sentences while checking for harmful content, PII, and policy violations."
            rows={8}
            maxLength={10000}
          />

          <div className="actions">
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? (
                <>
                  <span className="spinner" aria-hidden="true"></span>
                  Summarizing...
                </>
              ) : (
                'Summarize'
              )}
            </button>
            <button type="button" className="btn btn-secondary" onClick={handleClear}>
              Clear
            </button>
          </div>
        </form>

        {error && (
          <div className="result-card error-card" role="alert">
            <div className="card-header">
              <span className="status-text">⚠️ Error</span>
            </div>
            <p className="card-body">{error}</p>
          </div>
        )}

        {result && (
          <div className={`result-card ${result.status === 'success' ? 'success-card' : 'blocked-card'}`} role="status">
            <div className="card-header">
              <span className="status-text">
                {result.status === 'success' ? '✅ Summary Generated' : '🚫 Content Blocked'}
              </span>
            </div>

            <div className="card-body">
              {result.status === 'success' && (
                <div className="summary-section">
                  <h3>Summary</h3>
                  <p className="summary-text">{result.summary}</p>
                </div>
              )}

              {result.status === 'blocked' && (
                <div className="blocked-section">
                  <h3>Why it was blocked</h3>
                  {result.violations && result.violations.filter((v) => v.type !== 'content_filter').length > 0 ? (
                    <ul className="violations-list">
                      {result.violations
                        .filter((v) => v.type !== 'content_filter')
                        .map((v, i) => (
                          <li key={i} className="violation-item">
                            <strong>{v.category.replace(/_/g, ' ')}</strong>
                          </li>
                        ))}
                    </ul>
                  ) : (
                    <p className="blocked-reason">{result.reason}</p>
                  )}
                  <h3>Message</h3>
                  <p className="blocked-message">{result.message}</p>
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      <footer className="footer">
        <p>Built with AWS Lambda • Bedrock • Guardrails • DynamoDB • API Gateway</p>
      </footer>
    </div>
  )
}

export default App
