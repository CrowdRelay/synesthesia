(() => {
  if (!("serviceWorker" in navigator) || location.protocol !== "https:") return;
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" }).catch(() => {
      // Offline support is optional; the experience remains fully usable online.
    });
  });
})();
