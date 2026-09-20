# Daily use

For first-time setup, read [README.md](README.md) instead. This page is just the everyday routine.

## Start

Double-click **`start.bat`**.

A black window opens and prints a box. When you see `supermemory ready`, it's running.

**Leave that window open.** Closing it stops the server.

## Stop

Close the window, or press `Ctrl+C` in it.

## Check it's alive

```bash
curl http://localhost:6767/
```

`200` means it's up.

## Where things are

| What | Where |
|---|---|
| Program | WSL: `~/.supermemory/bin/supermemory-server` |
| Your memories | WSL: `~/.supermemory/data` (encrypted, never committed) |
| Settings | WSL: `~/.supermemory/env` |

From Windows Explorer, paste `\\wsl$\Ubuntu-24.04\home\<user>\.supermemory` into the address bar.

## Server API key

Printed in the window on every start, on the `api key` line. Starts with `sm_`.

You rarely need it — requests from the same machine (`localhost`) are allowed through without one.

## Using it from code

```ts
import Supermemory from "supermemory"

const client = new Supermemory({
  apiKey: "sm_...",                  // from the start.bat window
  baseURL: "http://localhost:6767",
})

await client.memories.add({ content: "...", containerTag: "user_1" })
```

Works only while the server window is open, and only on this PC. A deployed site (Vercel and similar) cannot reach `localhost`.
