# AI Content Guard - Frontend

React UI for the AI Content Guard text summarizer. Users input text, get AI-generated summaries, and see content safety violations when blocked.

## Tech Stack

- React 19
- Vite 8
- Plain CSS (dark mode, responsive)

## Features

- Text input with character counter (max 10,000)
- Loading spinner during API calls
- Auto-retry on server errors (2 retries with backoff)
- Success card — generated summary
- Blocked card — violation details (PII type)
- Error card — connectivity issues
- Dark mode (system preference)
- Mobile responsive

## Structure

```
frontend/
├── src/
│   ├── App.jsx          # Main component (form + result cards)
│   ├── App.css          # Component styles
│   ├── main.jsx         # React entry point
│   └── index.css        # Global styles + CSS variables
├── index.html           # HTML shell
├── .env.example         # API endpoint template
├── package.json
└── vite.config.js
```

## Setup

```bash
cd frontend
npm install
cp .env.example .env
```

Edit `.env` with your API Gateway URL:
```
VITE_API_URL=https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/summarize
```

## Development

```bash
npm run dev
```

Opens at http://localhost:5173/

## Deploy to Amplify

From the project root:
```bash
./deploy-frontend.sh
```

This reads the Amplify App ID from SSM, builds the app, and uploads to Amplify.

## Build for Production

```bash
npm run build
```

Output: `dist/` — static files for any hosting.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `VITE_API_URL` | API Gateway endpoint URL |
