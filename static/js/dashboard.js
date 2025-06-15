const apiKey = document.querySelector('meta[name="api-key"]').content;
const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
const wsUrl = `${protocol}//${window.location.host}/ws/${apiKey}`;

let ws;
let logs = [];
let allLogs = []; // Store all logs for filtering
let paused = false;
let autoScroll = true;
let totalLogs = 0;
let startTime = Date.now();
let logRates = [];
let currentSourceFilter = '';
let currentLevelFilter = '';

// LocalStorage functions
function getStorageKey(suffix = '') {
    return `logsy_${apiKey}${suffix ? '_' + suffix : ''}`;
}

function saveToStorage() {
    try {
        const data = {
            logs: allLogs.slice(-500), // Keep last 500 logs only
            totalLogs: totalLogs,
            startTime: startTime,
            autoScroll: autoScroll,
            currentSourceFilter: currentSourceFilter,
            currentLevelFilter: currentLevelFilter,
            timestamp: Date.now()
        };
        localStorage.setItem(getStorageKey(), JSON.stringify(data));
    } catch (e) {
        console.warn('Failed to save to localStorage:', e);
    }
}

function loadFromStorage() {
    try {
        const data = localStorage.getItem(getStorageKey());
        if (data) {
            const parsed = JSON.parse(data);

            // Only load if data is less than 1 hour old
            if (Date.now() - parsed.timestamp < 3600000) {
                allLogs = parsed.logs || [];
                totalLogs = parsed.totalLogs || 0;
                startTime = parsed.startTime || Date.now();
                autoScroll = parsed.autoScroll !== undefined ? parsed.autoScroll : true;
                currentSourceFilter = parsed.currentSourceFilter || '';
                currentLevelFilter = parsed.currentLevelFilter || '';

                // Restore UI state
                document.getElementById('sourceFilter').value = currentSourceFilter;
                document.getElementById('levelFilter').value = currentLevelFilter;
                document.getElementById('scrollBtn').classList.toggle('active', autoScroll);

                // Display cached logs
                applyFilters();
                updateStats();

                console.log(`Loaded ${allLogs.length} cached logs for API key ${apiKey}`);

                return true;
            }
        }
    } catch (e) {
        console.warn('Failed to load from localStorage:', e);
    }
    return false;
}

function clearStorage() {
    try {
        localStorage.removeItem(getStorageKey());
    } catch (e) {
        console.warn('Failed to clear localStorage:', e);
    }
}

function connect() {
    ws = new WebSocket(wsUrl);

    ws.onopen = function () {
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.innerHTML = '<span>🟢</span> Connected';
            statusEl.className = 'status connected';
        }
        document.getElementById('status-dot').className = 'status-dot connected';
    };

    ws.onmessage = function (event) {
        if (event.data === '💓') return; // Ignore heartbeat

        if (!paused) {
            totalLogs++;
            logRates.push(Date.now());
            // Keep only last minute of data
            const oneMinuteAgo = Date.now() - 60000;
            logRates = logRates.filter(time => time > oneMinuteAgo);

            // Parse log entry
            const logEntry = {
                timestamp: Date.now(),
                message: event.data,
                source: extractSource(event.data),
                level: extractLevel(event.data)
            };

            allLogs.push(logEntry);

            // Limit stored logs
            if (allLogs.length > 1000) {
                allLogs.shift();
            }

            // Apply current filters and display
            applyFilters();
            updateStats();

            // Save to localStorage every 10 logs or every 30 seconds
            if (totalLogs % 10 === 0) {
                saveToStorage();
            }
        }
    };

    ws.onclose = function () {
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.innerHTML = '<span>⚫</span> Disconnected';
            statusEl.className = 'status disconnected';
        }
        document.getElementById('status-dot').className = 'status-dot disconnected';
        // Reconnect after 3 seconds
        setTimeout(connect, 3000);
    };

    ws.onerror = function (error) {
        console.error('WebSocket error:', error);
    };
}

function extractSource(message) {
    if (message.includes('[fastapi-') || message.includes('[python-')) return 'fastapi';
    if (message.includes('[nginx-')) return 'nginx';
    if (message.includes('[system-')) return 'system';
    return 'custom';
}

function extractLevel(message) {
    const lowerMsg = message.toLowerCase();
    if (lowerMsg.includes('debug')) return 'debug';
    if (lowerMsg.includes('info')) return 'info';
    if (lowerMsg.includes('warn')) return 'warning';
    if (lowerMsg.includes('error')) return 'error';
    if (lowerMsg.includes('critical') || lowerMsg.includes('fatal')) return 'critical';
    return 'info'; // default
}

function applyFilters() {
    const filteredLogs = allLogs.filter(log => {
        const sourceMatch = !currentSourceFilter || log.source === currentSourceFilter;
        const levelMatch = !currentLevelFilter || log.level === currentLevelFilter;
        return sourceMatch && levelMatch;
    });

    displayLogs(filteredLogs);
}

function displayLogs(logsToShow) {
    const logsContainer = document.getElementById('logs');
    logsContainer.innerHTML = '';

    if (logsToShow.length === 0) {
        logsContainer.innerHTML = '<div class="empty-state">No logs match the current filters. Waiting for new logs...</div>';
        return;
    }

    logsToShow.forEach(log => {
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${log.level}`;
        logEntry.textContent = log.message;
        logsContainer.appendChild(logEntry);
    });

    // Auto-scroll to bottom
    if (autoScroll) {
        logsContainer.scrollTop = logsContainer.scrollHeight;
    }
}

function updateStats() {
    const totalLogsEl = document.getElementById('totalLogs');
    const logsPerMinuteEl = document.getElementById('logsPerMinute');
    const uptimeEl = document.getElementById('uptime');

    if (totalLogsEl) totalLogsEl.textContent = totalLogs;
    if (logsPerMinuteEl) logsPerMinuteEl.textContent = logRates.length;

    const uptimeMs = Date.now() - startTime;
    const uptimeSeconds = Math.floor(uptimeMs / 1000);
    const uptimeMinutes = Math.floor(uptimeSeconds / 60);
    const uptimeHours = Math.floor(uptimeMinutes / 60);

    let uptimeStr;
    if (uptimeHours > 0) {
        uptimeStr = `${uptimeHours}h ${uptimeMinutes % 60}m`;
    } else if (uptimeMinutes > 0) {
        uptimeStr = `${uptimeMinutes}m ${uptimeSeconds % 60}s`;
    } else {
        uptimeStr = `${uptimeSeconds}s`;
    }

    if (uptimeEl) uptimeEl.textContent = uptimeStr;
}

function copyApiKey() {
    navigator.clipboard.writeText(apiKey).then(() => {
        const elem = document.querySelector('.api-key');
        const original = elem.textContent;
        elem.textContent = '✅ Copied!';
        setTimeout(() => {
            elem.textContent = original;
        }, 2000);
    });
}

function copyScript() {
    console.log('copyScript function called');
    const scriptCommand = `curl -s https://raw.githubusercontent.com/deveshparagiri/logsy/main/script.sh | bash -s -- ${apiKey}`;
    const copyBtn = document.querySelector('.copy-script-btn');

    console.log('Script command:', scriptCommand);
    console.log('Copy button element:', copyBtn);

    if (!copyBtn) {
        console.error('Copy button not found!');
        return;
    }

    // Try clipboard API first
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(scriptCommand).then(() => {
            console.log('Clipboard API success');
            copyBtn.innerHTML = '✅ Copied!';
            copyBtn.classList.add('copied');

            setTimeout(() => {
                copyBtn.innerHTML = '📋 Script';
                copyBtn.classList.remove('copied');
            }, 2000);
        }).catch(err => {
            console.error('Clipboard API failed:', err);
            fallbackCopy();
        });
    } else {
        console.log('Clipboard API not available, using fallback');
        fallbackCopy();
    }

    function fallbackCopy() {
        try {
            const textarea = document.createElement('textarea');
            textarea.value = scriptCommand;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            const success = document.execCommand('copy');
            document.body.removeChild(textarea);

            if (success) {
                console.log('Fallback copy success');
                copyBtn.innerHTML = '✅ Copied!';
                copyBtn.classList.add('copied');

                setTimeout(() => {
                    copyBtn.innerHTML = '📋 Script';
                    copyBtn.classList.remove('copied');
                }, 2000);
            } else {
                console.error('Fallback copy failed');
                alert('Failed to copy script. Please copy manually: ' + scriptCommand);
            }
        } catch (err) {
            console.error('Fallback copy error:', err);
            alert('Failed to copy script. Please copy manually: ' + scriptCommand);
        }
    }
}

// Modal functions
function showStopModal() {
    document.getElementById('stopModal').classList.add('show');
}

function hideStopModal() {
    document.getElementById('stopModal').classList.remove('show');
}

// Copy command functions
function copyStopCommand() {
    copyToClipboard('sudo pkill -f "logsy_"', 'copyStopCommand');
}

function copyCheckCommand() {
    copyToClipboard('ps aux | grep logsy', 'copyCheckCommand');
}

function copyToClipboard(text, buttonId) {
    const button = event.target;

    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
            showCopySuccess(button);
        }).catch(() => {
            fallbackCopyToClipboard(text, button);
        });
    } else {
        fallbackCopyToClipboard(text, button);
    }
}

function fallbackCopyToClipboard(text, button) {
    try {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        const success = document.execCommand('copy');
        document.body.removeChild(textarea);

        if (success) {
            showCopySuccess(button);
        } else {
            alert('Failed to copy: ' + text);
        }
    } catch (err) {
        alert('Failed to copy: ' + text);
    }
}

function showCopySuccess(button) {
    const originalHTML = button.innerHTML;
    button.innerHTML = '✅';
    button.classList.add('copied');

    setTimeout(() => {
        button.innerHTML = originalHTML;
        button.classList.remove('copied');
    }, 2000);
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function () {
    // Controls
    document.getElementById('clearBtn').addEventListener('click', () => {
        allLogs = [];
        document.getElementById('logs').innerHTML = '<div class="empty-state">Logs cleared. Waiting for new logs...</div>';
        totalLogs = 0;
        logRates = [];
        updateStats();
        clearStorage(); // Clear localStorage when logs are manually cleared
    });

    document.getElementById('scrollBtn').addEventListener('click', function () {
        autoScroll = !autoScroll;
        this.classList.toggle('active', autoScroll);
        if (autoScroll) {
            document.getElementById('logs').scrollTop = document.getElementById('logs').scrollHeight;
        }
        saveToStorage(); // Save scroll preference
    });

    // Filters
    document.getElementById('sourceFilter').addEventListener('change', function () {
        currentSourceFilter = this.value;
        applyFilters();
        saveToStorage(); // Save filter preference
    });

    document.getElementById('levelFilter').addEventListener('change', function () {
        currentLevelFilter = this.value;
        applyFilters();
        saveToStorage(); // Save filter preference
    });

    // Update stats every second
    setInterval(updateStats, 1000);

    // Save to localStorage every 30 seconds
    setInterval(saveToStorage, 30000);

    // Initialize: Load cached data first, then connect
    const hasLoadedData = loadFromStorage();
    if (hasLoadedData) {
        // Show loading indicator for cached data
        document.getElementById('logs').innerHTML = '<div class="empty-state">📦 Loaded cached logs. Connecting to live stream...</div>';
    }

    // Connect to WebSocket
    connect();

    // Save data when page is about to unload
    window.addEventListener('beforeunload', saveToStorage);

    // Close modal on Escape key
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            hideStopModal();
        }
    });
}); 