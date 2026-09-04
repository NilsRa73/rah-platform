RAH Browser Bridge v1.2

PURPOSE
- ChatGPT assistant emits an explicit RAH_V1_TOOL marker.
- Browser extension reads the marker.
- Background service worker calls RAH Local Agent on 127.0.0.1:18779.
- Result is stored in chrome.storage.local.
- Content script sends RAH_AGENT_RESULT back to this ChatGPT conversation.
- Result is ACKed only after the same request_id is visibly present in a user message.

NEW IN v1.2
- DOM PROBE confirms ChatGPT composer and send-button state.
- END-TO-END CPU TEST from the extension popup.
- More robust text insertion and send strategies.
- Persistent diagnostics and state.
- Result remains queued when ChatGPT delivery is not confirmed.

INSTALL / UPDATE
1. Run UPGRADE-RAH-BROWSER-BRIDGE-v1.2.bat.
2. Open chrome://extensions or edge://extensions.
3. Press Reload on RAH Browser Bridge.
4. Return to ChatGPT and press F5 once.

MARKER
[[RAH_V1_TOOL {"request_id":"example","tool":"system.cpu","args":{}}]]

RESULT
RAH_AGENT_RESULT { ... }

SECURITY MODEL
- Agent listens on 127.0.0.1 only.
- Local calls use the per-machine bearer token.
- Read/write filesystem actions use the Windows account permissions of the local agent.
- Selected destructive/system actions remain separately gated and audited.
