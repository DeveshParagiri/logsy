# 🚀 Logsy - Real-time Log Streaming

Super simple log streaming SaaS. Stream your server logs to a dashboard in real-time.

## 🌟 Features

- **No signup required** - Just use any API key
- **Real-time streaming** - See logs as they happen
- **Zero setup** - One command to start streaming
- **Lightweight** - Runs on minimal resources

## 🚀 Quick Start

### For Users (Stream Your Logs)

1. **Get the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/deveshparagiri/logsy/main/script.sh
   chmod +x script.sh
   ```

2. **Start streaming**:
   ```bash
   ./script.sh YOUR_API_KEY logs/app.log
   ```

3. **View logs**: Visit `https://logsy.deveshparagiri.com` and enter your API key

### For Developers (Deploy Your Own)

## 🌐 Deploy to Railway (Free)

1. **Connect your GitHub repo to Railway**
2. **Add custom domain**: `logsy.deveshparagiri.com`
3. **Deploy** - Railway will automatically use the Dockerfile

Or use the Railway CLI:
```bash
npm install -g @railway/cli
railway login
railway link
railway up
```

## 📁 Project Structure

```
logsy/
├── app.py              # FastAPI backend
├── script.sh           # User onboarding script
├── Dockerfile          # Container config
├── requirements.txt    # Python dependencies
├── railway.json        # Railway config
└── README.md          # This file
```

## 🛠️ Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
uvicorn app:app --reload --port 8000

# Test the API
curl -X POST "http://localhost:8000/api/logs/test" \
  -H "Content-Type: application/json" \
  -d '{"log": "Hello from Logsy!"}'
```

## 🎯 User Flow

1. User visits your Logsy dashboard
2. User enters any API key (e.g., `my-production-logs`)
3. User runs the script on their server
4. Logs stream in real-time to the dashboard

---

**Built in 1 hour ⚡** 