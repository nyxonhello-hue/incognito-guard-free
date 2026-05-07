// Cross-browser shim
const api = typeof browser !== "undefined" ? browser : chrome;

api.runtime.onInstalled.addListener(() => {
  console.log("Incognito Guard installed");
});

// Chromium: tabs.onCreated fires with incognito flag
api.tabs.onCreated.addListener((tab) => {
  if (tab.incognito) {
    reportAndClose(tab.id);
  }
});

// Firefox: also listen for tab updates (extra safety)
if (typeof browser !== "undefined") {
  browser.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (tab.incognito) {
      reportAndClose(tabId);
    }
  });
}

function reportAndClose(tabId) {
  fetch("http://127.0.0.1:8765/incognito", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ timestamp: Date.now() })
  }).catch(err => console.error("Guard server unreachable:", err));

  if (tabId) {
    api.tabs.remove(tabId).catch(() => {});
  }
}
