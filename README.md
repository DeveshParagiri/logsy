# Logsy - Real-time Log Streaming

A lightweight, real-time log streaming service that allows you to stream server logs to a web dashboard with zero configuration.

## Features

- No registration required - use any API key
- Real-time log streaming via WebSocket
- Minimal setup with single command
- Lightweight and resource-efficient
- Web-based dashboard with filtering capabilities

## Quick Start

### Prerequisites

- Python 3.7+
- curl (for downloading the streaming script)

### For Log Streaming

1. Download the streaming script:
   ```bash
   curl -O https://raw.githubusercontent.com/username/logsy/main/script.sh
   chmod +x script.sh
   ```

2. Start streaming your logs:
   ```bash
   ./script.sh YOUR_API_KEY /path/to/your/logfile.log
   ```

3. Access the dashboard at your deployed URL and enter your API key

### For Self-Hosting

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/username/logsy.git
   cd logsy
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the application:
   ```bash
   uvicorn app:app --host 0.0.0.0 --port 8000
   ```

## Deployment

### Railway

1. Connect your GitHub repository to Railway
2. Deploy using the included Dockerfile
3. Set up your custom domain

### Docker

```bash
docker build -t logsy .
docker run -p 8000:8000 logsy
```

## API Reference

### Stream Logs
```bash
POST /api/logs/{api_key}
Content-Type: application/json

{
  "log": "Your log message here"
}
```

### WebSocket Connection
```javascript
ws://your-domain.com/ws/{api_key}
```

## Project Structure

```
logsy/
├── app.py                 # FastAPI application
├── script.sh             # Client streaming script
├── templates/            # HTML templates
│   ├── dashboard.html   # Dashboard interface
│   └── landing.html     # Landing page
├── static/              # Static assets
│   ├── css/            # Stylesheets
│   └── js/             # JavaScript files
├── Dockerfile          # Container configuration
├── requirements.txt    # Python dependencies
├── railway.json       # Railway deployment config
└── README.md          # Documentation
```

## Usage

1. Deploy the Logsy service to your preferred platform
2. Share your dashboard URL with users
3. Users enter any API key to create a log stream
4. Use the provided script to stream logs from any server
5. View real-time logs in the web dashboard

## Development

```bash
# Install development dependencies
pip install -r requirements.txt

# Run with auto-reload
uvicorn app:app --reload --port 8000

# Test the API
curl -X POST "http://localhost:8000/api/logs/test" \
  -H "Content-Type: application/json" \
  -d '{"log": "Test log message"}'
```