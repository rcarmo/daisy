---
applyTo: "**/*.ts"
---

# Bun/TypeScript Instructions

## General Guidelines

- Use Bun built-in APIs for file I/O, HTTP server, and WebSocket/SSE
- Prefer `Bun.file()` over `fs` module when possible
- Use `Bun.serve()` for HTTP servers
- Use native `fs.watch()` for file watching (works with Bun)

## Code Style

- Use TypeScript strict mode
- Prefer `const` over `let`
- Use async/await, avoid callbacks
- Use template literals for string interpolation
- Export types alongside implementations

## Bun-Specific Patterns

```typescript
// File reading
const file = Bun.file(path);
const text = await file.text();
const stats = await file.stat();

// HTTP Server
Bun.serve({
  port: 3000,
  fetch(req) {
    return new Response("Hello");
  }
});

// SSE Response
const stream = new ReadableStream({
  start(controller) {
    controller.enqueue(`data: ${JSON.stringify(data)}\n\n`);
  }
});
return new Response(stream, {
  headers: { 'Content-Type': 'text/event-stream' }
});
```

## Error Handling

- Always handle potential errors from file operations
- Use try/catch for async operations
- Provide meaningful error messages
