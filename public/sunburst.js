/**
 * Daisy - Sunburst Chart Renderer
 * Custom SVG-based sunburst visualization
 */

// State
let currentTree = null;
let previousTree = null;
let zoomStack = [];
let eventSource = null;
let removedHighlightPaths = new Set();
let removedHighlightTimer = null;

// DOM Elements
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

// Configuration
const config = {
  innerRadius: 60,
  maxDepth: 6,
  minAngleForLabel: 5, // degrees
};

/**
 * Format bytes to human-readable string
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
}

/**
 * Convert polar to cartesian coordinates
 */
function polarToCartesian(cx, cy, radius, angleDeg) {
  const angleRad = (angleDeg - 90) * Math.PI / 180;
  return {
    x: cx + radius * Math.cos(angleRad),
    y: cy + radius * Math.sin(angleRad)
  };
}

/**
 * Generate SVG arc path
 */
function describeArc(cx, cy, innerR, outerR, startAngle, endAngle) {
  // Handle full circle case
  if (endAngle - startAngle >= 359.999) {
    endAngle = startAngle + 359.999;
  }
  
  const start1 = polarToCartesian(cx, cy, outerR, startAngle);
  const end1 = polarToCartesian(cx, cy, outerR, endAngle);
  const start2 = polarToCartesian(cx, cy, innerR, endAngle);
  const end2 = polarToCartesian(cx, cy, innerR, startAngle);
  
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  
  return [
    `M ${start1.x} ${start1.y}`,
    `A ${outerR} ${outerR} 0 ${largeArc} 1 ${end1.x} ${end1.y}`,
    `L ${start2.x} ${start2.y}`,
    `A ${innerR} ${innerR} 0 ${largeArc} 0 ${end2.x} ${end2.y}`,
    'Z'
  ].join(' ');
}

/**
 * Get color for a node based on angle (rainbow effect)
 */
function getColor(startAngle, depth) {
  const hue = (startAngle / 360) * 360;
  const saturation = Math.max(30, 70 - depth * 10);
  const lightness = Math.min(70, 45 + depth * 5);
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

/**
 * Render the sunburst chart
 */
function renderSunburst(root, zoomRoot = null) {
  svg.innerHTML = '';
  
  const viewRoot = zoomRoot || root;
  const ringWidth = (350 - config.innerRadius) / config.maxDepth;
  
  // Update center label
  centerSize.textContent = formatBytes(viewRoot.size);
  centerName.textContent = viewRoot.name;
  
  // Update header
  pathEl.textContent = root.path;
  totalSizeEl.textContent = formatBytes(root.size);
  
  // Recursive render function
  function renderNode(node, startAngle, endAngle, depth, parentAngle = 0) {
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
      
      // Skip tiny segments
      if (childAngle < 0.5) {
        currentAngle = childEndAngle;
        continue;
      }
      
      // Create path element
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', describeArc(0, 0, innerR, outerR, currentAngle, childEndAngle));
      path.setAttribute('fill', getColor(currentAngle, depth));
      if (removedHighlightPaths.has(child.path)) {
        path.classList.add('removed');
      }
      path.dataset.path = child.path;
      path.dataset.name = child.name;
      path.dataset.size = child.size;
      path.dataset.isDirectory = child.isDirectory;
      
      // Event listeners
      path.addEventListener('mouseenter', handleMouseEnter);
      path.addEventListener('mouseleave', handleMouseLeave);
      path.addEventListener('mousemove', handleMouseMove);
      path.addEventListener('click', handleClick);
      
      svg.appendChild(path);
      
      // Render children
      if (child.isDirectory && child.children) {
        renderNode(child, currentAngle, childEndAngle, depth + 1, currentAngle);
      }
      
      currentAngle = childEndAngle;
    }
  }
  
  // Start rendering from root
  renderNode(viewRoot, 0, 360, 1);
  
  // Update breadcrumb
  updateBreadcrumb(viewRoot, root);
}

/**
 * Update breadcrumb navigation
 */
function updateBreadcrumb(viewRoot, fullRoot) {
  breadcrumb.innerHTML = '';
  
  // Build path from root to viewRoot
  const path = [];
  let current = fullRoot;
  
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
    crumb.addEventListener('click', () => zoomTo(node));
    breadcrumb.appendChild(crumb);
  }
}

/**
 * Find node by path
 */
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

/**
 * Collect all paths in a tree into a set.
 */
function collectPaths(node, set) {
  set.add(node.path);
  if (node.children) {
    for (const child of node.children) {
      collectPaths(child, set);
    }
  }
}

/**
 * Compute removed paths between two trees.
 */
function computeRemovedPaths(prev, next) {
  if (!prev || !next) return [];

  const prevPaths = new Set();
  const nextPaths = new Set();

  collectPaths(prev, prevPaths);
  collectPaths(next, nextPaths);

  const removed = [];
  for (const path of prevPaths) {
    if (!nextPaths.has(path)) removed.push(path);
  }
  return removed;
}

/**
 * Build a set of existing parent paths for removed items.
 */
function buildRemovedHighlightPaths(removed, nextTree) {
  const highlights = new Set();
  if (!removed.length || !nextTree) return highlights;

  const nextPaths = new Set();
  collectPaths(nextTree, nextPaths);

  for (const removedPath of removed) {
    let current = removedPath;
    while (current.includes('/')) {
      current = current.substring(0, current.lastIndexOf('/')) || '/';
      if (nextPaths.has(current)) {
        highlights.add(current);
      }
      if (current === '/') break;
    }
  }

  return highlights;
}

/**
 * Build zoom stack from root to a target path.
 */
function buildZoomStack(root, targetPath) {
  if (!targetPath) return [root];

  const stack = [];

  function walk(node) {
    stack.push(node);
    if (node.path === targetPath) return true;
    if (node.children) {
      for (const child of node.children) {
        if (targetPath.startsWith(child.path)) {
          if (walk(child)) return true;
        }
      }
    }
    stack.pop();
    return false;
  }

  if (walk(root)) return stack;
  return [root];
}

/**
 * Apply a new tree update while preserving zoom when possible.
 */
function applyTreeUpdate(tree, setConnected) {
  const previousViewPath = zoomStack.length > 0 ? zoomStack[zoomStack.length - 1].path : null;
  const removed = computeRemovedPaths(previousTree, tree);

  currentTree = tree;
  previousTree = tree;

  svg.classList.add('updating');

  if (previousViewPath) {
    zoomStack = buildZoomStack(currentTree, previousViewPath);
    const viewRoot = zoomStack[zoomStack.length - 1];
    renderSunburst(currentTree, viewRoot);
  } else {
    zoomStack = [currentTree];
    renderSunburst(currentTree);
  }

  if (setConnected) {
    setStatus('connected', 'Connected');
  }

  if (removed.length > 0) {
    removedHighlightPaths = buildRemovedHighlightPaths(removed, currentTree);
    if (removedHighlightTimer) clearTimeout(removedHighlightTimer);
    removedHighlightTimer = setTimeout(() => {
      removedHighlightPaths = new Set();
      const viewRoot = zoomStack.length > 0 ? zoomStack[zoomStack.length - 1] : currentTree;
      renderSunburst(currentTree, viewRoot);
    }, 1500);
  }

  requestAnimationFrame(() => {
    svg.classList.remove('updating');
  });
}

/**
 * Zoom to a specific node
 */
function zoomTo(node) {
  if (!currentTree) return;
  
  const targetNode = typeof node === 'string' 
    ? findNode(currentTree, node) 
    : node;
    
  if (targetNode && targetNode.isDirectory) {
    zoomStack.push(targetNode);
    renderSunburst(currentTree, targetNode);
  }
}

/**
 * Zoom out one level
 */
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

/**
 * Mouse event handlers
 */
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
  tooltip.style.left = `${e.clientX + 15}px`;
  tooltip.style.top = `${e.clientY + 15}px`;
}

function handleClick(e) {
  const path = e.target;
  if (path.dataset.isDirectory === 'true') {
    zoomTo(path.dataset.path);
  }
}

/**
 * Set status
 */
function setStatus(status, text) {
  statusText.textContent = text;
  statusText.className = status;
  document.body.classList.toggle('scanning', status === 'scanning');
}

/**
 * Connect to SSE endpoint
 */
function connect() {
  if (eventSource) {
    eventSource.close();
  }
  
  setStatus('', 'Connecting...');
  eventSource = new EventSource('/api/events');
  
  eventSource.onopen = () => {
    setStatus('connected', 'Connected');
  };
  
  eventSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'full':
          applyTreeUpdate(data.data, true);
          break;

        case 'snapshot':
          applyTreeUpdate(data.data, false);
          break;
          
        case 'scanning':
          setStatus('scanning', `Scanning... (${data.progress} items)`);
          break;
          
        case 'error':
          setStatus('error', `Error: ${data.message}`);
          break;
      }
    } catch (err) {
      console.error('Failed to parse SSE message:', err);
    }
  };
  
  eventSource.onerror = () => {
    setStatus('error', 'Disconnected');
    setTimeout(connect, 3000);
  };
}

/**
 * Request rescan
 */
async function rescan() {
  try {
    await fetch('/api/rescan');
  } catch (err) {
    console.error('Rescan failed:', err);
  }
}

// Event listeners
rescanBtn.addEventListener('click', rescan);
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' || e.key === 'Backspace') {
    zoomOut();
  }
});

// Click on center to zoom out
document.getElementById('center-label').addEventListener('click', zoomOut);

// Initialize
connect();
