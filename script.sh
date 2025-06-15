#!/bin/bash
# logsy_shipper.sh - Interactive Log Shipper

# Check if first argument is a command
COMMAND="$1"

# Handle management commands
case "$COMMAND" in
    "stop")
        echo "🛑 Stopping all Logsy background processes..."
        
        # Kill all logsy processes
        LOGSY_PIDS=$(ps aux | grep -i "logsy_" | grep -v grep | awk '{print $2}')
        if [ -n "$LOGSY_PIDS" ]; then
            echo "📋 Found running processes: $LOGSY_PIDS"
            echo "$LOGSY_PIDS" | xargs sudo kill 2>/dev/null
            sleep 2
            
            # Force kill if still running
            REMAINING_PIDS=$(ps aux | grep -i "logsy_" | grep -v grep | awk '{print $2}')
            if [ -n "$REMAINING_PIDS" ]; then
                echo "🔨 Force killing stubborn processes..."
                echo "$REMAINING_PIDS" | xargs sudo kill -9 2>/dev/null
            fi
            
            echo "✅ All Logsy processes stopped"
        else
            echo "ℹ️  No Logsy processes found running"
        fi
        
        # Clean up temp files
        echo "🧹 Cleaning up temporary files..."
        rm -f /tmp/logsy_*.pid /tmp/logsy_*.log 2>/dev/null
        
        echo "🎉 Cleanup complete!"
        exit 0
        ;;
    
    "status")
        echo "📊 Logsy Status Check"
        echo "===================="
        
        # Check for running processes
        LOGSY_PIDS=$(ps aux | grep -i "logsy_" | grep -v grep)
        if [ -n "$LOGSY_PIDS" ]; then
            echo "🟢 Running Processes:"
            echo "$LOGSY_PIDS" | while read -r line; do
                pid=$(echo "$line" | awk '{print $2}')
                echo "   PID: $pid"
            done
            echo ""
        else
            echo "🔴 No Logsy processes running"
            echo ""
        fi
        
        # Check for PID files
        PID_FILES=$(ls /tmp/logsy_*.pid 2>/dev/null)
        if [ -n "$PID_FILES" ]; then
            echo "📄 PID Files found:"
            for pidfile in $PID_FILES; do
                api_key=$(basename "$pidfile" .pid | sed 's/logsy_//')
                echo "   $pidfile → API key: logsy_$api_key"
            done
            echo ""
        fi
        
        # Check for log files
        LOG_FILES=$(ls /tmp/logsy_*.log 2>/dev/null)
        if [ -n "$LOG_FILES" ]; then
            echo "📝 Log Files found:"
            for logfile in $LOG_FILES; do
                size=$(du -h "$logfile" 2>/dev/null | cut -f1)
                echo "   $logfile ($size)"
            done
        fi
        
        exit 0
        ;;
        
    "list")
        echo "📋 Available Logsy Commands"
        echo "=========================="
        echo ""
        echo "🚀 Start streaming:"
        echo "   $0 <API_KEY> [LOGSY_URL]"
        echo "   Example: $0 logsy_abc123"
        echo ""
        echo "🛑 Stop all processes:"
        echo "   $0 stop"
        echo ""
        echo "📊 Check status:"
        echo "   $0 status"
        echo ""
        echo "❓ Show this help:"
        echo "   $0 list"
        echo ""
        exit 0
        ;;
        
    "help"|"-h"|"--help")
        echo "🚀 Logsy Interactive Log Shipper"
        echo "================================"
        echo ""
        echo "📖 Usage:"
        echo "   $0 <API_KEY> [LOGSY_URL]    # Start log streaming"
        echo "   $0 stop                     # Stop all background processes"
        echo "   $0 status                   # Check running processes"
        echo "   $0 list                     # Show available commands"
        echo ""
        echo "💡 Examples:"
        echo "   $0 logsy_abc123                           # Start with API key"
        echo "   $0 logsy_abc123 https://mylogsy.com       # Custom URL"
        echo "   $0 stop                                   # Stop everything"
        echo ""
        exit 0
        ;;
esac

# Original functionality - streaming mode
API_KEY="$1"
LOGSY_URL="${2:-https://www.logsy.info}"

if [ -z "$API_KEY" ]; then
    echo "❌ Usage: $0 <API_KEY> [LOGSY_URL]"
    echo "💡 Or try: $0 list (to see all commands)"
    echo "Example: $0 logsy_my-secret-key"
    exit 1
fi

echo "🚀 Logsy Interactive Setup"
echo "📡 API Key: $API_KEY"
echo "🌐 Logsy URL: $LOGSY_URL"
echo ""

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local response
    while true; do
        printf "%s (y/n): " "$question"
        read -r response < /dev/tty
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
        case "$response" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Ask user what types of logs they want
echo "📋 What types of logs do you want to stream?"
echo ""

WANT_FASTAPI=false
WANT_NGINX=false
WANT_SYSTEM=false

if ask_yes_no "🐍 FastAPI/Python app logs"; then
    WANT_FASTAPI=true
fi

if ask_yes_no "🌐 Nginx web server logs"; then
    WANT_NGINX=true
fi

if ask_yes_no "💻 System logs (syslog, messages)"; then
    WANT_SYSTEM=true
fi

echo ""

# Check if user selected anything
if [ "$WANT_FASTAPI" = false ] && [ "$WANT_NGINX" = false ] && [ "$WANT_SYSTEM" = false ]; then
    echo "❌ No log types selected! Please run again and choose at least one."
    exit 1
fi

echo "✅ Selected log types:"
[ "$WANT_FASTAPI" = true ] && echo "   🐍 FastAPI logs"
[ "$WANT_NGINX" = true ] && echo "   🌐 Nginx logs"
[ "$WANT_SYSTEM" = true ] && echo "   💻 System logs"
echo ""

# Arrays to store found log files and their prefixes
LOG_FILES=()
LOG_PREFIXES=()

# Function to add log file
add_log_file() {
    local file="$1"
    local prefix="$2"
    if [ -f "$file" ] && [ -r "$file" ]; then
        LOG_FILES+=("$file")
        LOG_PREFIXES+=("$prefix")
        echo "✅ Found: $file"
        return 0
    fi
    return 1
}

# Handle FastAPI logs
if [ "$WANT_FASTAPI" = true ]; then
    echo "🔍 Looking for FastAPI logs..."
    
    # Check default logs/ directory
    if [ -d "logs" ]; then
        echo "📁 Found logs/ directory"
        found_any=false
        
        # Check for common FastAPI log files
        for log_name in app.log error.log debug.log access.log application.log; do
            if add_log_file "logs/$log_name" "fastapi-$(basename "$log_name" .log)"; then
                found_any=true
            fi
        done
        
        # Check for any other .log files in logs/
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            # Skip if we already found this file
            already_added=false
            for existing_file in "${LOG_FILES[@]}"; do
                if [ "$existing_file" = "$file" ]; then
                    already_added=true
                    break
                fi
            done
            if [ "$already_added" = false ]; then
                if add_log_file "$file" "fastapi-$(basename "$file" .log)"; then
                    found_any=true
                fi
            fi
        done < <(find logs -name "*.log" -type f -print0 2>/dev/null)
        
        if [ "$found_any" = false ]; then
            echo "⚠️  No .log files found in logs/ directory"
        fi
    else
        echo "❗ logs/ directory not found in current location"
        echo ""
        echo -n "📂 Enter your FastAPI logs directory path: "
        read -r custom_logs_dir < /dev/tty
        
        if [ -n "$custom_logs_dir" ] && [ -d "$custom_logs_dir" ]; then
            echo "📁 Found custom directory: $custom_logs_dir"
            found_any=false
            
            while IFS= read -r -d '' file; do
                if add_log_file "$file" "fastapi-$(basename "$file" .log)"; then
                    found_any=true
                fi
            done < <(find "$custom_logs_dir" -name "*.log" -type f -print0 2>/dev/null)
            
            if [ "$found_any" = false ]; then
                echo "⚠️  No .log files found in $custom_logs_dir"
            fi
        else
            echo "❌ Directory '$custom_logs_dir' not found!"
            echo ""
            echo "💡 Please run this script from your FastAPI project directory"
            echo "   Your project should have a logs/ folder with .log files"
            echo ""
            echo "🔧 Or configure your FastAPI app to log to files first:"
            echo "   mkdir -p logs"
            echo "   # Configure logging in your FastAPI app"
        fi
    fi
    echo ""
fi

# Handle Nginx logs
if [ "$WANT_NGINX" = true ]; then
    echo "🔍 Looking for Nginx logs..."
    
    nginx_locations=(
        "/var/log/nginx/access.log"
        "/var/log/nginx/error.log"
        "/usr/local/var/log/nginx/access.log"
        "/usr/local/var/log/nginx/error.log"
        "/opt/nginx/logs/access.log"
        "/opt/nginx/logs/error.log"
    )
    
    for log_file in "${nginx_locations[@]}"; do
        if add_log_file "$log_file" "nginx-$(basename "$log_file" .log)"; then
            continue
        fi
    done
    echo ""
fi

# Handle System logs
if [ "$WANT_SYSTEM" = true ]; then
    echo "🔍 Looking for System logs..."
    
    system_locations=(
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/system.log"
    )
    
    for log_file in "${system_locations[@]}"; do
        if add_log_file "$log_file" "system-$(basename "$log_file" .log)"; then
            continue
        fi
    done
    echo ""
fi

# Check if we found any log files
if [ ${#LOG_FILES[@]} -eq 0 ]; then
    echo "❌ No readable log files found!"
    echo ""
    echo "💡 Troubleshooting:"
    [ "$WANT_FASTAPI" = true ] && echo "   🐍 For FastAPI: Make sure you're in your project directory with a logs/ folder"
    [ "$WANT_NGINX" = true ] && echo "   🌐 For Nginx: Check if Nginx is installed and running"
    [ "$WANT_SYSTEM" = true ] && echo "   💻 For System: Try running with sudo for system log access"
    echo ""
    echo "🔧 Run the script from the right directory or check your log configuration!"
    exit 1
fi

echo "🎉 Ready to stream ${#LOG_FILES[@]} log files:"
for i in "${!LOG_FILES[@]}"; do
    echo "   📄 ${LOG_FILES[$i]} → [${LOG_PREFIXES[$i]}]"
done
echo ""

# Ask if user wants to run in background
RUN_IN_BACKGROUND=false
if ask_yes_no "🔄 Would you like to run Logsy in the background"; then
    RUN_IN_BACKGROUND=true
fi
echo ""

# Function to send log with prefix
send_log() {
    local prefix="$1"
    local line="$2"
    local prefixed_log="[$prefix] $line"
    
    curl -s -X POST "$LOGSY_URL/api/logs/$API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"log\": \"$prefixed_log\"}" > /dev/null
}

if [ "$RUN_IN_BACKGROUND" = true ]; then
    # Background mode
    echo "🔄 Starting Logsy in background mode..."
    echo "✨ Visit $LOGSY_URL and use API key: $API_KEY"
    echo ""
    
    # Create a background script
    LOGSY_PID_FILE="/tmp/logsy_${API_KEY##*_}.pid"
    LOGSY_LOG_FILE="/tmp/logsy_${API_KEY##*_}.log"
    
    # Start all log streaming in background
    (
        echo "$(date): Logsy background streaming started" >> "$LOGSY_LOG_FILE"
        echo "$(date): Streaming ${#LOG_FILES[@]} log files" >> "$LOGSY_LOG_FILE"
        
        # Start tailing all log files in parallel
        TAIL_PIDS=()
        
        for i in "${!LOG_FILES[@]}"; do
            log_file="${LOG_FILES[$i]}"
            prefix="${LOG_PREFIXES[$i]}"
            
            echo "$(date): Watching $log_file → [$prefix]" >> "$LOGSY_LOG_FILE"
            
            # Start tail in background for each file
            (
                tail -n0 -F "$log_file" | while read -r LINE; do
                    prefixed_log="[$prefix] $LINE"
                    # Escape quotes and backslashes for JSON
                    escaped_log=$(echo "$prefixed_log" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
                    curl -s -X POST "$LOGSY_URL/api/logs/$API_KEY" \
                        -H "Content-Type: application/json" \
                        -d "{\"log\": \"$escaped_log\"}" > /dev/null
                done
            ) &
            
            TAIL_PIDS+=($!)
        done
        
        # Save PIDs for cleanup
        printf "%s\n" "${TAIL_PIDS[@]}" > "$LOGSY_PID_FILE"
        
        # Wait for all background processes
        wait
    ) &
    
    MAIN_PID=$!
    echo "$MAIN_PID" >> "$LOGSY_PID_FILE"
    
    echo "✅ Logsy is now running in the background!"
    echo "📊 Process ID: $MAIN_PID"
    echo "📄 Log file: $LOGSY_LOG_FILE"
    echo "🔧 PID file: $LOGSY_PID_FILE"
    echo ""
    echo "🛑 To stop Logsy background streaming:"
    echo "   kill $MAIN_PID"
    echo "   # Or kill all processes:"
    echo "   while read pid; do kill \$pid 2>/dev/null; done < $LOGSY_PID_FILE"
    echo ""
    echo "📊 Logs will appear in your dashboard with prefixes like:"
    for prefix in "${LOG_PREFIXES[@]}"; do
        echo "   [$prefix] Log message here..."
    done
    echo ""
    echo "🎉 Background streaming started! You can close this terminal."
    
else
    # Foreground mode (original behavior)
    echo "🔍 Starting log streaming..."
    echo "✨ Visit $LOGSY_URL and use API key: $API_KEY"
    echo "💡 Press Ctrl+C to stop"
    echo "---"

    # Start tailing all log files in parallel
    TAIL_PIDS=()

    for i in "${!LOG_FILES[@]}"; do
        log_file="${LOG_FILES[$i]}"
        prefix="${LOG_PREFIXES[$i]}"
        
        echo "🟢 Watching: $log_file → [$prefix]"
        
        # Start tail in background for each file
        (
            tail -n0 -F "$log_file" | while read -r LINE; do
                prefixed_log="[$prefix] $LINE"
                # Escape quotes and backslashes for JSON
                escaped_log=$(echo "$prefixed_log" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
                curl -s -X POST "$LOGSY_URL/api/logs/$API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{\"log\": \"$escaped_log\"}" > /dev/null
            done
        ) &
        
        TAIL_PIDS+=($!)
    done

    echo ""
    echo "📊 Streaming live! Logs will appear in your dashboard with prefixes like:"
    for prefix in "${LOG_PREFIXES[@]}"; do
        echo "   [$prefix] Log message here..."
    done

    # Function to cleanup background processes
    cleanup() {
        echo ""
        echo "🛑 Stopping log streaming..."
        for pid in "${TAIL_PIDS[@]}"; do
            kill "$pid" 2>/dev/null
        done
        echo "👋 Goodbye!"
        exit 0
    }

    # Handle Ctrl+C
    trap cleanup SIGINT SIGTERM

    # Wait for all background processes
    wait
fi
