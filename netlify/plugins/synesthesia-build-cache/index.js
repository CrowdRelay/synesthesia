const crypto = require("node:crypto");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");

const VERSION = "4.7.1-stable";
const RELEASE = "4.7.1.stable";
const EDITOR_SHA256 = "c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba";
const cacheRoot = path.join(".cache", `godot-${VERSION}`);
const editor = path.join(cacheRoot, "editor.zip");
const templateDir = path.join(cacheRoot, "godot-data", "export_templates", RELEASE);
const manifest = path.join(templateDir, ".synesthesia-web-templates.sha256");
const templateNames = ["web_dlink_nothreads_debug.zip", "web_dlink_nothreads_release.zip"];
const templates = templateNames.map((name) => path.join(templateDir, name));
const paths = [editor, manifest, ...templates];

async function fileSha256(file) {
  const hash = crypto.createHash("sha256");
  await new Promise((resolve, reject) => {
    const stream = fs.createReadStream(file);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", resolve);
  });
  return hash.digest("hex");
}

async function verifiedEditor() {
  try {
    return (await fileSha256(editor)) === EDITOR_SHA256;
  } catch {
    return false;
  }
}

async function verifiedTemplates() {
  try {
    const lines = (await fsp.readFile(manifest, "utf8"))
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
    if (lines.length !== templateNames.length) return false;
    const expected = new Map();
    for (const line of lines) {
      const match = line.match(/^([0-9a-f]{64})\s+(.+)$/);
      if (!match || !templateNames.includes(match[2])) return false;
      expected.set(match[2], match[1]);
    }
    if (expected.size !== templateNames.length) return false;
    for (const name of templateNames) {
      if ((await fileSha256(path.join(templateDir, name))) !== expected.get(name)) return false;
    }
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  onPreBuild: async ({ utils }) => {
    await utils.cache.restore(paths);
    console.log("SYNESTHESIA_NETLIFY_CACHE=RESTORE scope=editor+2-web-templates+integrity-manifest");
  },
  // onEnd also runs after a failed build. Save only independently verified
  // inputs so a late Rust/Godot failure does not force another 1.2 GiB template
  // download, while a partial/corrupt download can never poison the next run.
  onEnd: async ({ utils }) => {
    const save = [];
    if (await verifiedEditor()) save.push(editor);
    if (await verifiedTemplates()) save.push(manifest, ...templates);
    if (save.length > 0) await utils.cache.save(save);
    console.log(`SYNESTHESIA_NETLIFY_CACHE=CHECKPOINT verified=${save.length} scope=bounded-inputs`);
  },
};
