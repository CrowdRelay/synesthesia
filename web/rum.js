(() => {
  if (Math.random() >= 0.05) return;
  const endpoint = "https://signal-api.virya.music/v1/public/telemetry/rum";
  const deviceClass = innerWidth < 768 ? "mobile" : innerWidth < 1200 ? "tablet" : "desktop";
  const sent = new Set();
  function report(metricKey, value, metadata = {}) {
    if (!Number.isFinite(value) || value < 0 || sent.has(metricKey)) return;
    sent.add(metricKey);
    fetch(endpoint, {
      method: "POST", mode: "cors", credentials: "omit", keepalive: true,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ surface: "synesthesia", metric_key: metricKey, value, route: location.pathname.slice(0,160), device_class: deviceClass, metadata, observed_at: new Date().toISOString() }),
    }).catch(() => {});
  }
  addEventListener("synesthesia:interactive", (event) => report("boot_interactive_ms", Number(event.detail?.durationMs || performance.now())), { once: true });
  let lastFrame = performance.now();
  let worstHitch = 0;
  let frames = 0;
  function frame(now) {
    worstHitch = Math.max(worstHitch, Math.max(0, now - lastFrame - 16.7));
    lastFrame = now;
    if (++frames < 300) requestAnimationFrame(frame);
    else if (worstHitch >= 25) report("frame_hitch_ms", worstHitch);
  }
  requestAnimationFrame(frame);
  addEventListener("synesthesia:room-loaded", (event) => report("room_load_ms", Number(event.detail?.durationMs || 0)), { once: true });
  addEventListener("synesthesia:transition-complete", (event) => report("transition_ms", Number(event.detail?.durationMs || 0)), { once: true });
})();
