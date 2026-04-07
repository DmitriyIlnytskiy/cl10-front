// server.js
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
  console.log('✅ Flutter client connected!');
  
  // Simulate React's reconciler calling createInstance() 
  // and sending the command over the bridge after a short delay
  setTimeout(() => {
    const payload = {
      op: "create",
      id: "n1",
      type: "container",
      props: {
        width: 200,
        height: 200,
        color: "blue",
        text: "Hello from Node.js!"
      }
    };
    
    ws.send(JSON.stringify(payload));
    console.log('📤 Sent creation command to Flutter:', payload);
  }, 2000);
});

console.log('🚀 Node.js WebSocket server listening on ws://localhost:8080');