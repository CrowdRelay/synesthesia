(() => {
  const removeBoot = () => {
    const boot = document.getElementById('synesthesia-boot');
    if (!boot || boot.dataset.ready === 'true') return;
    boot.dataset.ready = 'true';
    window.setTimeout(() => boot.remove(), 340);
  };
  window.synesthesiaBootReady = removeBoot;
  // Never conceal an engine/export error indefinitely.
  window.setTimeout(removeBoot, 30000);
})();
