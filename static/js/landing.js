let currentApiKey = '';

async function getStarted() {
    document.getElementById('loading').style.display = 'block';
    document.querySelector('.action-buttons').style.display = 'none';
    document.querySelector('.features').style.display = 'none';

    try {
        const response = await fetch('/api/generate-key', { method: 'POST' });
        const data = await response.json();
        currentApiKey = data.api_key;

        // Update UI
        document.getElementById('apiKeyDisplay').textContent = currentApiKey;
        document.getElementById('commandBox').textContent = `curl -s https://raw.githubusercontent.com/deveshparagiri/logsy/main/script.sh | bash -s -- ${currentApiKey}`;
        document.getElementById('dashboardBtn').href = `/dashboard?key=${currentApiKey}`;

        // Show command section
        document.getElementById('loading').style.display = 'none';
        document.getElementById('commandSection').style.display = 'block';
        document.body.classList.add('command-active');
        document.querySelector('.container').classList.add('command-active');
        document.querySelector('.hero').classList.add('command-active');

    } catch (error) {
        alert('Error generating API key. Please try again.');
        document.getElementById('loading').style.display = 'none';
        document.querySelector('.action-buttons').style.display = 'flex';
        document.querySelector('.features').style.display = 'grid';
    }
}

async function copyCommand() {
    const command = document.getElementById('commandBox').textContent;
    const copyBtn = document.getElementById('copyBtn');

    try {
        await navigator.clipboard.writeText(command);
        copyBtn.innerHTML = '✅ Copied!';
        copyBtn.classList.add('copied');

        setTimeout(() => {
            copyBtn.innerHTML = '📋 Copy';
            copyBtn.classList.remove('copied');
        }, 2000);
    } catch (error) {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = command;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);

        copyBtn.innerHTML = '✅ Copied!';
        copyBtn.classList.add('copied');

        setTimeout(() => {
            copyBtn.innerHTML = '📋 Copy';
            copyBtn.classList.remove('copied');
        }, 2000);
    }
}

async function copyApiKey() {
    const copyBtn = document.querySelector('.api-key-container .copy-icon-inline');

    try {
        await navigator.clipboard.writeText(currentApiKey);
        copyBtn.innerHTML = '✅';
        copyBtn.classList.add('copied');

        setTimeout(() => {
            copyBtn.innerHTML = '📋';
            copyBtn.classList.remove('copied');
        }, 2000);
    } catch (error) {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = currentApiKey;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);

        copyBtn.innerHTML = '✅';
        copyBtn.classList.add('copied');

        setTimeout(() => {
            copyBtn.innerHTML = '📋';
            copyBtn.classList.remove('copied');
        }, 2000);
    }
} 