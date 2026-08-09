(() => {
  const CACHE_PREFIX = "virya-synesthesia-";
  const CACHE_ID = "__SYNESTHESIA_CACHE_ID__";
  const CACHE_MARKER = "synesthesia:web-cache-id";
  let removed = false;
  let migrationActive = false;
  let bootVideoTimer = 0;

  function readCacheMarker() {
    try {
      return window.localStorage.getItem(CACHE_MARKER);
    } catch (_) {
      return null;
    }
  }

  function writeCacheMarker(value) {
    try {
      window.localStorage.setItem(CACHE_MARKER, value);
    } catch (_) {
      // Storage can be disabled; startup must remain functional without it.
    }
  }

  async function clearSynesthesiaCaches() {
    if (!("caches" in window)) return;
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX)).map((key) => caches.delete(key)));
  }

  async function unregisterSynesthesiaWorkers() {
    if (!("serviceWorker" in navigator)) return;
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map(async (registration) => {
      const script = registration.active?.scriptURL || registration.waiting?.scriptURL || registration.installing?.scriptURL || "";
      if (!script) return;
      try {
        const url = new URL(script);
        if (url.origin === location.origin && url.pathname === "/service-worker.js") {
          await registration.unregister();
        }
      } catch (_) {
        // Ignore a malformed/opaque registration and leave unrelated workers alone.
      }
    }));
  }

  function migrateControlledDeploy() {
    if (!("serviceWorker" in navigator) || !navigator.serviceWorker.controller) {
      writeCacheMarker(CACHE_ID);
      return;
    }
    if (readCacheMarker() === CACHE_ID) return;

    // A page controlled by the previous worker can otherwise mix an old cached
    // PCK with the new HTML/JS after a deploy. Clean once per deploy and reload
    // outside the stale controller before Godot becomes interactive.
    migrationActive = true;
    writeCacheMarker(CACHE_ID);
    Promise.allSettled([clearSynesthesiaCaches(), unregisterSynesthesiaWorkers()])
      .finally(() => location.reload());
  }

  function bootElement() {
    return document.getElementById("synesthesia-boot");
  }

  function bootVideoElement() {
    return document.getElementById("synesthesia-boot-eye");
  }

  function shouldAnimateBootVideo() {
    if (removed || migrationActive) return false;
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) return false;
    const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    if (connection?.saveData) return false;
    return !["slow-2g", "2g"].includes(connection?.effectiveType || "");
  }

  function armBootVideo() {
    bootVideoTimer = 0;
    if (!shouldAnimateBootVideo()) return;
    const video = bootVideoElement();
    const boot = bootElement();
    if (!video || !boot || boot.dataset.ready === "true") return;
    if (!video.getAttribute("src")) {
      video.src = "/menu-eye-boot-loop.mp4";
      video.load();
    }
    const play = video.play();
    if (play && typeof play.catch === "function") play.catch(() => undefined);
  }

  function stopBootVideo() {
    if (bootVideoTimer) {
      window.clearTimeout(bootVideoTimer);
      bootVideoTimer = 0;
    }
    const video = bootVideoElement();
    if (!video) return;
    try { video.pause(); } catch (_) {}
    video.removeAttribute("src");
    try { video.load(); } catch (_) {}
  }

  function scheduleBootVideo() {
    if (!shouldAnimateBootVideo() || bootVideoTimer) return;
    // Fast boots never fetch/decode the extra loop. Slow boots become animated
    // after the instant poster has already painted.
    bootVideoTimer = window.setTimeout(armBootVideo, 350);
  }

  function statusElement() {
    return document.getElementById("synesthesia-boot-status");
  }

  function updateNativeLabel() {
    if (removed || migrationActive) return;
    const el = bootElement();
    if (!el || el.dataset.stalled === "true") return;
    const status = statusElement();
    if (!status) return;
    // Keep technical viewport diagnostics out of the artwork by default. They
    // remain one query flag away for QA without leaking into the public splash.
    if (!new URLSearchParams(location.search).has("debug-ui")) {
      status.textContent = "URUCHAMIAM DOŚWIADCZENIE";
      return;
    }
    const dpr = Math.min(Math.max(window.devicePixelRatio || 1, 1), 3);
    const viewport = window.visualViewport;
    const cssWidth = Math.max(1, Math.round(viewport?.width || window.innerWidth || document.documentElement.clientWidth || 1));
    const cssHeight = Math.max(1, Math.round(viewport?.height || window.innerHeight || document.documentElement.clientHeight || 1));
    const width = Math.round(cssWidth * dpr);
    const height = Math.round(cssHeight * dpr);
    status.textContent = `NATIVE ${width}×${height} · DPR ${dpr.toFixed(2)}`;
  }

  function showStalled(message) {
    if (removed || migrationActive) return;
    const el = bootElement();
    if (!el) return;
    el.dataset.stalled = "true";
    const status = statusElement();
    if (status) status.textContent = message || "START TRWA DŁUŻEJ NIŻ ZWYKLE";
  }

  function removeBoot() {
    if (removed || migrationActive) return;
    removed = true;
    stopBootVideo();
    const el = bootElement();
    if (!el) return;
    el.dataset.ready = "true";
    window.setTimeout(() => el.remove(), 260);
  }

  function wireRetry() {
    const button = document.getElementById("synesthesia-boot-retry");
    if (!button) return;
    button.addEventListener("click", () => {
      if (migrationActive) return;
      migrationActive = true;
      button.disabled = true;
      const status = statusElement();
      if (status) status.textContent = "CZYSZCZĘ CACHE · URUCHAMIAM PONOWNIE";
      writeCacheMarker(CACHE_ID);
      Promise.allSettled([clearSynesthesiaCaches(), unregisterSynesthesiaWorkers()])
        .finally(() => location.reload());
    }, { once: true });
  }

  function wireDom() {
    wireRetry();
    updateNativeLabel();
    scheduleBootVideo();
  }

  migrateControlledDeploy();
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", wireDom, { once: true });
  } else {
    wireDom();
  }
  window.addEventListener("resize", updateNativeLabel, { passive: true });
  window.visualViewport?.addEventListener("resize", updateNativeLabel, { passive: true });

  // Godot calls prepare first, then arms its authored Theora loop, then fades
  // this shell. This prevents two decoders from running through the handoff.
  window.synesthesiaBootPrepareHandoff = stopBootVideo;
  window.synesthesiaBootReady = removeBoot;
  window.synesthesiaBootFailed = (message) => showStalled(message);

  // Never silently hide a failed engine boot. Give a deterministic recovery
  // action instead; a slow but healthy Godot start can still call BootReady.
  window.setTimeout(() => showStalled("START TRWA DŁUŻEJ NIŻ ZWYKLE"), 12000);
})();
