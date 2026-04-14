const WebSocket = require('ws');
const React = require('react');
const Reconciler = require('react-reconciler');
const Yoga = require('yoga-layout-prebuilt');
const EventEmitter = require('events'); 

const eventBus = new EventEmitter(); 

const wss = new WebSocket.Server({ port: 8080 });
let clientSocket = null;

function sendIPC(msg) {
  if (clientSocket && clientSocket.readyState === WebSocket.OPEN) {
    clientSocket.send(JSON.stringify(msg));
    console.log("📤 Sent to Flutter:", msg.op, msg.id || "");
  }
}

let nextId = 1;

function createWidgetInstance(type, props) {
  const id = `n${nextId++}`;
  const yogaNode = Yoga.Node.create();
  
  if (props.width) yogaNode.setWidth(props.width);
  if (props.height) yogaNode.setHeight(props.height);
  if (props.flexDirection === 'row') yogaNode.setFlexDirection(Yoga.FLEX_DIRECTION_ROW);
  if (props.padding) yogaNode.setPadding(Yoga.EDGE_ALL, props.padding);

  // THE FIX: Tag it as text so Yoga doesn't crush its width to 0!
  const isText = type === 'text';

  return { id, type, props, children: [], yogaNode, isText };
}

const hostConfig = {
  supportsMutation: true,
  isPrimaryRenderer: false,
  warnsIfNotActing: false,
  scheduleTimeout: setTimeout,
  cancelTimeout: clearTimeout,
  noTimeout: -1,

  getRootHostContext: () => ({}),
  getChildHostContext: () => ({}),
  prepareForCommit: () => null,
  shouldSetTextContent: () => false,

  createInstance: (type, props) => {
    const { children, ...cleanProps } = props;
    const instance = createWidgetInstance(type, cleanProps);
    sendIPC({ op: "create", id: instance.id, type, props: cleanProps });
    return instance;
  },

  createTextInstance: (text) => {
    const id = `t${nextId++}`;
    sendIPC({ op: "create", id, type: "text", props: { text } });
    return { id, type: "text", text, isText: true };
  },

  appendInitialChild: (parent, child) => {
    parent.children.push(child);
    if (!child.isText) parent.yogaNode.insertChild(child.yogaNode, parent.yogaNode.getChildCount());
    sendIPC({ op: "appendChild", parentId: parent.id, childId: child.id });
  },

  appendChild: (parent, child) => {
    parent.children.push(child);
    if (!child.isText) parent.yogaNode.insertChild(child.yogaNode, parent.yogaNode.getChildCount());
    sendIPC({ op: "appendChild", parentId: parent.id, childId: child.id });
  },

  appendChildToContainer: (container, child) => {
    container.children.push(child);
    if (!child.isText) container.yogaNode.insertChild(child.yogaNode, container.yogaNode.getChildCount());
    sendIPC({ op: "appendChild", parentId: container.id, childId: child.id });
  },

  removeChild: (parent, child) => {
    parent.children = parent.children.filter(c => c.id !== child.id);
    if (!child.isText) parent.yogaNode.removeChild(child.yogaNode);
    sendIPC({ op: "removeChild", parentId: parent.id, childId: child.id });
  },

  prepareUpdate: (instance, type, oldProps, newProps) => newProps !== oldProps ? newProps : null,

  commitUpdate: (instance, updatePayload, type, oldProps, newProps) => {
    instance.props = newProps;
    if (newProps.width) instance.yogaNode.setWidth(newProps.width);
    if (newProps.height) instance.yogaNode.setHeight(newProps.height);
    const { children, ...cleanProps } = newProps;
    sendIPC({ op: "update", id: instance.id, props: cleanProps });
  },

  resetAfterCommit: (container) => {
    container.yogaNode.calculateLayout(Yoga.UNDEFINED, Yoga.UNDEFINED, Yoga.DIRECTION_LTR);
    
    function sendLayout(node) {
      if (node.isText) return;
      const layout = node.yogaNode.getComputedLayout();
      sendIPC({ 
        op: "layout", id: node.id, 
        x: layout.left, y: layout.top, w: layout.width, h: layout.height 
      });
      node.children.forEach(sendLayout);
    }
    sendLayout(container);
  },

  finalizeInitialChildren: () => false,
  clearContainer: () => {},
  commitTextUpdate: (textInstance, oldText, newText) => {
    sendIPC({ op: "update", id: textInstance.id, props: { text: newText } });
  }
};

const CustomRenderer = Reconciler(hostConfig);

function App() {
  const [count, setCount] = React.useState(0);

  // This hook listens for clicks coming over the WebSocket!
  React.useEffect(() => {
    const handleClick = (targetId) => {
      if (targetId === 'btn-1') {
        setCount(prev => prev + 1); // Update React State!
      }
    };
    
    eventBus.on('click', handleClick);
    return () => eventBus.off('click', handleClick);
  }, []);

  return React.createElement('container', { padding: 20, flexDirection: 'row' },
    // We wrap the text in a container so Yoga gives it 150px of space
    React.createElement('container', { width: 150, height: 40 },
      React.createElement('text', { text: `Counter: ${count}` })
    ),
    React.createElement('button', { 
      text: "Add +1",
      width: 100,
      height: 40,
      id: "btn-1" 
    })
  );
}

wss.on('connection', (ws) => {
  console.log('✅ Target process connected.');
  clientSocket = ws;

  const rootContainer = { 
    id: 'root', type: 'root', children: [], 
    yogaNode: Yoga.Node.create() 
  };
  rootContainer.yogaNode.setWidth(800);
  rootContainer.yogaNode.setHeight(600);

  // The '0' here tells React 18 to use a Legacy (Synchronous) Root!
  const container = CustomRenderer.createContainer(rootContainer, 0, false, null);
  CustomRenderer.updateContainer(React.createElement(App), container, null, null);

  ws.on('message', (message) => {
    const data = JSON.parse(message);
    if (data.event === 'click') {
      console.log(`👆 Click received from Flutter! Updating React state for ${data.targetId}...`);
      eventBus.emit('click', data.targetId); // <-- Route to React
    }
  });
});

console.log('🚀 React 18 Custom Reconciler listening on ws://localhost:8080');