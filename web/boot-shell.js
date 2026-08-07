(() => {
  const boot = () => document.getElementById('synesthesia-boot');
  const updateNativeLabel = () => {
    const label = document.querySelector('.synesthesia-boot__render');
    if (!label) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 3);
    const width = Math.round(window.innerWidth * dpr);
    const height = Math.round(window.innerHeight * dpr);
    label.textContent = `ADAPTIVE NATIVE · ${width}×${height} · DPR ${dpr.toFixed(2)}`;
  };
  const glitch = () => {
    const node = boot();
    if (!node || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    node.dataset.glitch = 'true';
    window.setTimeout(() => { if (node) node.dataset.glitch = 'false'; }, 260);
  };
  const removeBoot = () => {
    const node = boot();
    if (!node || node.dataset.ready === 'true') return;
    glitch();
    node.dataset.ready = 'true';
    window.setTimeout(() => node.remove(), 340);
  };
  updateNativeLabel();
  window.addEventListener('resize', updateNativeLabel, { passive: true });
  window.setInterval(glitch, 4300);
  window.synesthesiaBootReady = removeBoot;
  window.setTimeout(removeBoot, 30000);
})();
