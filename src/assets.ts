/**
 * Daisy - Embedded Static Assets
 *
 * This module contains all front-end assets embedded as strings,
 * allowing the binary to be fully self-contained.
 */

export const INDEX_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Daisy - Disk Usage Visualizer</title>
  <style>STYLE_PLACEHOLDER</style>
</head>
<body>
  <div id="app">
    <main>
      <div id="chart-container">
        <svg id="sunburst" viewBox="-400 -400 800 800"></svg>
        <div id="center-label">
          <div id="center-size">-</div>
          <div id="center-name">-</div>
        </div>
      </div>
      
      <div id="tooltip" class="hidden">
        <div id="tooltip-name"></div>
        <div id="tooltip-size"></div>
        <div id="tooltip-path"></div>
      </div>
    </main>
    
    <div id="info-panel">
      <span id="total-size">-</span>
      <span id="path">-</span>
      <span id="status"><span id="status-text">⏳</span></span>
      <button id="rescan-btn" title="Rescan">🔄</button>
      <div id="breadcrumb"></div>
    </div>
  </div>
  
  <script>SCRIPT_PLACEHOLDER</script>
</body>
</html>`;

export const STYLE_CSS = `* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

:root {
  --bg-color: #1e1e2e;
  --text-color: #cdd6f4;
  --text-muted: #6c7086;
  --accent-color: #89b4fa;
  --surface-color: #313244;
  --border-color: #45475a;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg-color);
  color: var(--text-color);
  min-height: 100vh;
  overflow: hidden;
}

#app {
  min-height: 100vh;
  position: relative;
}

main {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 1rem;
}

#chart-container {
  position: relative;
  width: min(90vw, 90vh);
  height: min(90vw, 90vh);
}

#sunburst {
  width: 100%;
  height: 100%;
}

#sunburst path {
  stroke: var(--bg-color);
  stroke-width: 1px;
  cursor: pointer;
  transition: fill 1s ease-out, opacity 0.2s;
}

#sunburst path:hover {
  opacity: 0.8;
}

#sunburst path.changed {
  filter: brightness(1.3) saturate(1.2);
  stroke: rgba(255, 255, 255, 0.5);
  stroke-width: 2px;
}

#center-label {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  text-align: center;
  pointer-events: none;
  background: var(--bg-color);
  border-radius: 50%;
  width: 120px;
  height: 120px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  pointer-events: auto;
}

#center-size {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text-color);
}

#center-name {
  font-size: 0.8rem;
  color: var(--text-muted);
  max-width: 100px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Floating info panel */
#info-panel {
  position: fixed;
  bottom: 0.5rem;
  right: 0.5rem;
  background: var(--surface-color);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.3rem 0.5rem;
  font-size: 0.7rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  z-index: 100;
  opacity: 0.7;
  transition: opacity 0.2s;
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

#info-panel:hover {
  opacity: 1;
}

#path {
  color: var(--text-muted);
  font-size: 0.65rem;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

#total-size {
  color: var(--accent-color);
  font-weight: 600;
  font-size: 0.75rem;
}

#breadcrumb {
  display: none;
}

.crumb {
  color: var(--text-muted);
  cursor: pointer;
  padding: 0.125rem 0.25rem;
  border-radius: 3px;
  transition: all 0.2s;
  font-size: 0.65rem;
}

.crumb:hover {
  color: var(--text-color);
  background: var(--border-color);
}

.crumb::after {
  content: ' /';
  color: var(--border-color);
  margin-left: 0.25rem;
}

.crumb:last-child {
  color: var(--accent-color);
}

.crumb:last-child::after {
  content: '';
}

#status {
  color: var(--text-muted);
}

#status-text {
  font-size: 0.7rem;
}

#status-text.connected {
  color: #a6e3a1;
}

#status-text.scanning {
  color: #f9e2af;
}

#status-text.error {
  color: #f38ba8;
}

#rescan-btn {
  background: transparent;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  font-size: 0.7rem;
  padding: 0;
  transition: all 0.2s;
}

#rescan-btn:hover {
  color: var(--text-color);
}

#rescan-btn:active {
  transform: scale(0.9);
}

/* Tooltip */
#tooltip {
  position: fixed;
  background: var(--surface-color);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.75rem 1rem;
  pointer-events: none;
  z-index: 1000;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  max-width: 300px;
}

#tooltip.hidden {
  display: none;
}

#tooltip-name {
  font-weight: 600;
  margin-bottom: 0.25rem;
}

#tooltip-size {
  color: var(--accent-color);
  font-size: 0.9rem;
}

#tooltip-path {
  color: var(--text-muted);
  font-size: 0.75rem;
  margin-top: 0.25rem;
  word-break: break-all;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.scanning #rescan-btn {
  animation: spin 1s linear infinite;
}

@media (max-width: 768px) {
  #info-panel {
    left: 1rem;
    right: 1rem;
    max-width: none;
  }
  
  #center-label {
    width: 80px;
    height: 80px;
  }
  
  #center-size {
    font-size: 1rem;
  }
  
  #center-name {
    font-size: 0.7rem;
    max-width: 70px;
  }
}`;

export const SUNBURST_JS = `/**
 * Daisy - Sunburst Chart Renderer
 */

let currentTree = null;
let previousSizes = new Map();
let zoomStack = [];
let eventSource = null;
let reconnectTimer = null;

const svg = document.getElementById('sunburst');
const centerSize = document.getElementById('center-size');
const centerName = document.getElementById('center-name');
const pathEl = document.getElementById('path');
const totalSizeEl = document.getElementById('total-size');
const statusText = document.getElementById('status-text');
const rescanBtn = document.getElementById('rescan-btn');
const tooltip = document.getElementById('tooltip');
const tooltipName = document.getElementById('tooltip-name');
const tooltipSize = document.getElementById('tooltip-size');
const tooltipPath = document.getElementById('tooltip-path');
const breadcrumb = document.getElementById('breadcrumb');

const config = {
  innerRadius: 60,
  maxDepth: 6,
  minAngleForLabel: 5,
};

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return (bytes / Math.pow(k, i)).toFixed(1) + ' ' + sizes[i];
}

function polarToCartesian(cx, cy, radius, angleDeg) {
  const angleRad = (angleDeg - 90) * Math.PI / 180;
  return {
    x: cx + radius * Math.cos(angleRad),
    y: cy + radius * Math.sin(angleRad)
  };
}

function describeArc(cx, cy, innerR, outerR, startAngle, endAngle) {
  if (endAngle - startAngle >= 359.999) {
    endAngle = startAngle + 359.999;
  }
  const start1 = polarToCartesian(cx, cy, outerR, startAngle);
  const end1 = polarToCartesian(cx, cy, outerR, endAngle);
  const start2 = polarToCartesian(cx, cy, innerR, endAngle);
  const end2 = polarToCartesian(cx, cy, innerR, startAngle);
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  return [
    'M ' + start1.x + ' ' + start1.y,
    'A ' + outerR + ' ' + outerR + ' 0 ' + largeArc + ' 1 ' + end1.x + ' ' + end1.y,
    'L ' + start2.x + ' ' + start2.y,
    'A ' + innerR + ' ' + innerR + ' 0 ' + largeArc + ' 0 ' + end2.x + ' ' + end2.y,
    'Z'
  ].join(' ');
}

function getColor(startAngle, depth, highlight) {
  const hue = (startAngle / 360) * 360;
  const saturation = highlight ? 90 : Math.max(30, 70 - depth * 10);
  const lightness = highlight ? 75 : Math.min(70, 45 + depth * 5);
  return 'hsl(' + hue + ', ' + saturation + '%, ' + lightness + '%)';
}

function renderSunburst(root, zoomRoot, isUpdate) {
  const viewRoot = zoomRoot || root;
  const ringWidth = (350 - config.innerRadius) / config.maxDepth;
  centerSize.textContent = formatBytes(viewRoot.size);
  centerName.textContent = viewRoot.name;
  pathEl.textContent = root.path;
  totalSizeEl.textContent = formatBytes(root.size);

  // Build new sizes map
  const newSizes = new Map();
  function collectSizes(node) {
    newSizes.set(node.path, node.size);
    if (node.children) {
      for (const child of node.children) {
        collectSizes(child);
      }
    }
  }
  collectSizes(root);

  // Find changed paths
  const changedPaths = new Set();
  if (isUpdate && previousSizes.size > 0) {
    for (const [path, size] of newSizes) {
      const oldSize = previousSizes.get(path);
      if (oldSize === undefined || oldSize !== size) {
        changedPaths.add(path);
      }
    }
  }

  // Clear and render
  svg.innerHTML = '';

  function renderNode(node, startAngle, endAngle, depth) {
    if (depth > config.maxDepth) return;
    if (!node.children || node.children.length === 0) return;
    const innerR = config.innerRadius + (depth - 1) * ringWidth;
    const outerR = config.innerRadius + depth * ringWidth;
    let currentAngle = startAngle;
    const angleRange = endAngle - startAngle;
    for (const child of node.children) {
      if (child.size === 0) continue;
      const childAngle = (child.size / node.size) * angleRange;
      const childEndAngle = currentAngle + childAngle;
      if (childAngle < 0.5) {
        currentAngle = childEndAngle;
        continue;
      }
      const isChanged = changedPaths.has(child.path);
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', describeArc(0, 0, innerR, outerR, currentAngle, childEndAngle));
      path.setAttribute('fill', getColor(currentAngle, depth, isChanged));
      path.dataset.path = child.path;
      path.dataset.name = child.name;
      path.dataset.size = child.size;
      path.dataset.isDirectory = child.isDirectory;
      path.dataset.angle = currentAngle;
      path.dataset.depth = depth;
      if (isChanged) {
        path.classList.add('changed');
      }
      path.addEventListener('mouseenter', handleMouseEnter);
      path.addEventListener('mouseleave', handleMouseLeave);
      path.addEventListener('mousemove', handleMouseMove);
      path.addEventListener('click', handleClick);
      svg.appendChild(path);
      if (child.isDirectory && child.children) {
        renderNode(child, currentAngle, childEndAngle, depth + 1);
      }
      currentAngle = childEndAngle;
    }
  }
  renderNode(viewRoot, 0, 360, 1);
  updateBreadcrumb(viewRoot, root);

  // Fade out highlights after animation
  if (changedPaths.size > 0) {
    setTimeout(function() {
      const changedElements = svg.querySelectorAll('.changed');
      for (const el of changedElements) {
        const angle = parseFloat(el.dataset.angle);
        const depth = parseInt(el.dataset.depth);
        el.style.transition = 'fill 1s ease-out';
        el.setAttribute('fill', getColor(angle, depth, false));
        el.classList.remove('changed');
      }
    }, 100);
  }

  // Update previous sizes
  previousSizes = newSizes;
}

function updateBreadcrumb(viewRoot, fullRoot) {
  breadcrumb.innerHTML = '';
  const path = [];
  function findPath(node, targetPath) {
    if (node.path === targetPath) {
      path.push(node);
      return true;
    }
    if (node.children) {
      for (const child of node.children) {
        if (targetPath.startsWith(child.path)) {
          path.push(node);
          return findPath(child, targetPath);
        }
      }
    }
    return false;
  }
  findPath(fullRoot, viewRoot.path);
  for (const node of path) {
    const crumb = document.createElement('span');
    crumb.className = 'crumb';
    crumb.textContent = node.name || 'Root';
    crumb.dataset.path = node.path;
    crumb.addEventListener('click', function() { zoomTo(node); });
    breadcrumb.appendChild(crumb);
  }
}

function findNode(root, targetPath) {
  if (root.path === targetPath) return root;
  if (root.children) {
    for (const child of root.children) {
      const found = findNode(child, targetPath);
      if (found) return found;
    }
  }
  return null;
}

function zoomTo(node) {
  if (!currentTree) return;
  const targetNode = typeof node === 'string' ? findNode(currentTree, node) : node;
  if (targetNode && targetNode.isDirectory) {
    zoomStack.push(targetNode);
    renderSunburst(currentTree, targetNode);
  }
}

function zoomOut() {
  if (zoomStack.length > 1) {
    zoomStack.pop();
    const parent = zoomStack[zoomStack.length - 1];
    renderSunburst(currentTree, parent);
  } else {
    zoomStack = [];
    renderSunburst(currentTree);
  }
}

function handleMouseEnter(e) {
  const path = e.target;
  tooltip.classList.remove('hidden');
  tooltipName.textContent = path.dataset.name;
  tooltipSize.textContent = formatBytes(parseInt(path.dataset.size));
  tooltipPath.textContent = path.dataset.path;
}

function handleMouseLeave() {
  tooltip.classList.add('hidden');
}

function handleMouseMove(e) {
  tooltip.style.left = (e.clientX + 15) + 'px';
  tooltip.style.top = (e.clientY + 15) + 'px';
}

function handleClick(e) {
  const path = e.target;
  if (path.dataset.isDirectory === 'true') {
    zoomTo(path.dataset.path);
  }
}

function setStatus(status, text) {
  const icons = { connected: '✓', scanning: '⏳', error: '✗', '': '⏳' };
  statusText.textContent = icons[status] || '⏳';
  statusText.className = status;
  statusText.title = text;
  document.body.classList.toggle('scanning', status === 'scanning');
}

function connect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  if (eventSource) {
    eventSource.close();
    eventSource = null;
  }
  setStatus('', 'Connecting...');
  eventSource = new EventSource('/api/events');
  eventSource.onopen = function() {
    setStatus('connected', 'Connected');
  };
  eventSource.onmessage = function(event) {
    try {
      const data = JSON.parse(event.data);
      switch (data.type) {
        case 'full':
          const isUpdate = currentTree !== null;
          currentTree = data.data;
          // Preserve zoom state if we have a valid path
          if (zoomStack.length > 0) {
            const currentPath = zoomStack[zoomStack.length - 1].path;
            const node = findNode(currentTree, currentPath);
            if (node) {
              zoomStack = [];
              // Rebuild zoom stack
              function buildStack(root, targetPath) {
                zoomStack.push(root);
                if (root.path === targetPath) return true;
                if (root.children) {
                  for (const child of root.children) {
                    if (targetPath.startsWith(child.path)) {
                      return buildStack(child, targetPath);
                    }
                  }
                }
                return false;
              }
              buildStack(currentTree, currentPath);
              renderSunburst(currentTree, zoomStack[zoomStack.length - 1], isUpdate);
            } else {
              zoomStack = [currentTree];
              renderSunburst(currentTree, null, isUpdate);
            }
          } else {
            zoomStack = [currentTree];
            renderSunburst(currentTree, null, isUpdate);
          }
          setStatus('connected', 'Updated');
          break;
        case 'scanning':
          setStatus('scanning', 'Scanning ' + data.progress + ' items');
          break;
        case 'error':
          setStatus('error', data.message);
          break;
      }
    } catch (err) {
      console.error('Failed to parse SSE message:', err);
    }
  };
  eventSource.onerror = function() {
    setStatus('error', 'Disconnected');
    if (eventSource) {
      eventSource.close();
      eventSource = null;
    }
    reconnectTimer = setTimeout(connect, 3000);
  };
}

async function rescan() {
  try {
    await fetch('/api/rescan');
  } catch (err) {
    console.error('Rescan failed:', err);
  }
}

rescanBtn.addEventListener('click', rescan);
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape' || e.key === 'Backspace') {
    zoomOut();
  }
});
document.getElementById('center-label').addEventListener('click', zoomOut);
connect();`;

/**
 * Get the fully assembled HTML with CSS and JS inlined
 */
export function getIndexHtml(): string {
  return INDEX_HTML.replace("STYLE_PLACEHOLDER", STYLE_CSS).replace(
    "SCRIPT_PLACEHOLDER",
    SUNBURST_JS,
  );
}
