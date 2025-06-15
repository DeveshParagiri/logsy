from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import asyncio
import json
from datetime import datetime
from collections import defaultdict
import secrets

app = FastAPI(title="Logsy - Real-time Log Streaming")

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Templates
templates = Jinja2Templates(directory="templates")

# In-memory storage: {api_key: [connected_websockets]}
connections = defaultdict(list)

@app.post("/api/generate-key")
async def generate_api_key():
    """Generate a unique API key for the user"""
    # Generate longer, more complex API key (32 characters)
    api_key = f"logsy_{secrets.token_urlsafe(32)}"
    return {"api_key": api_key}

@app.post("/api/logs/{api_key}")
async def receive_log(api_key: str, request: Request):
    data = await request.json()
    log_entry = f"[{datetime.now().strftime('%H:%M:%S')}] {data.get('log', '')}"
    
    # Broadcast to all connected clients for this API key
    for websocket in connections[api_key]:
        try:
            await websocket.send_text(log_entry)
        except:
            # Remove disconnected clients
            connections[api_key].remove(websocket)
    
    return {"status": "received"}

@app.websocket("/ws/{api_key}")
async def websocket_endpoint(websocket: WebSocket, api_key: str):
    await websocket.accept()
    connections[api_key].append(websocket)
    
    try:
        # Send welcome message
        await websocket.send_text(f"🚀 Connected to Logsy! Waiting for logs from key: {api_key}")
        # Keep connection alive
        while True:
            await asyncio.sleep(30)
            await websocket.send_text("💓")  # Heartbeat
    except:
        connections[api_key].remove(websocket)

@app.get("/dashboard/{api_key}", response_class=HTMLResponse)
async def dashboard(request: Request, api_key: str):
    """Dashboard for viewing logs with a specific API key"""
    return templates.TemplateResponse("dashboard.html", {"request": request, "api_key": api_key})

@app.get("/", response_class=HTMLResponse)
async def landing_page(request: Request):
    """Landing page with API key generation"""
    return templates.TemplateResponse("landing.html", {"request": request})

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "active_connections": sum(len(conns) for conns in connections.values())}

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard_home(request: Request):
    """Dashboard home for returning users to enter their API key"""
    return templates.TemplateResponse("dashboard_home.html", {"request": request})