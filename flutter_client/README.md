# React-to-Flutter Custom Renderer (PoC)

This project is a Proof of Concept (PoC) for a custom React renderer utilizing a **two-process architecture**. It demonstrates how to decouple React's reconciliation engine from the target rendering platform by bridging Node.js and Flutter via WebSockets.

## Architecture

The system is split into two distinct processes communicating over an IPC boundary (WebSockets):

```text
Node.js Process              Target Process (Flutter)
+-------------------+        +-------------------+
| React Components  |        | Platform Runtime  |
|       |           |        |                   |
|  reconciler       |  IPC   |  Widget Registry  |
|       |           | (JSON) |       |           |
|  hostConfig  -----+------->|  Create/Update/   |
|       |           |        |  Remove widgets   |
|  Yoga layout      |        |       |           |
|  Layout msgs -----+------->|  Render to screen |
+-------------------+        +-------------------+