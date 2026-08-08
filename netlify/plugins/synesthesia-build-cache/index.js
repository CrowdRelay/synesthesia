const crypto = require("node:crypto");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");

const VERSION = "4.7.1-stable";
const RELEASE = "4.7.1.stable";
const EDITOR_SHA256 = "c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba";
const cacheRoot = path.join(".cache", `godot-${VERSION}`);
const editor = path.join(cacheRoot, "editor.zip");

// Match Godot's Linux data-dir contract exactly:
//   $XDG_DATA_HOME/godot/export_templates/<version>
// build-web-preview.sh exports XDG_DATA_HOME=$cacheRoot/godot-data on Netlify.
const xdgDataHome = path.join(cacheRoot, "godot-data");
const godotDataDir = path.join(xdgDataHome, "godot");
const templateDir = path.join(godotDataDir, "export_templates", RELEASE);
const manifest = path.join(templateDir, ".synesthesia-web-templates.sha256");
const templateNames = ["web_dlink_nothreads_debug.zip", "web_dlink_nothreads_release.zip"];
const templates = templateNames.map((name) => path.join(templateDir, name));

// V3 before the Netlify path fix cached the same verified files one directory
// too high. Restore that bounded legacy cache once and migrate it so the first
// fixed deploy does not download the 1.2 GiB official template pack again.
const legacyTemplateDir = path.join(cacheRoot, "godot-data", "export_templates", RELEASE);
const legacyManifest = path.join(legacyTemplateDir, ".synesthesia-web-templates.sha256");
const legacyTemplates = templateNames.map((name) => path.join(legacyTemplateDir, name));
const restorePaths = [editor, manifest, ...templates, legacyManifest, ...legacyTemplates];

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

async function verifiedTemplatesAt(dir) {
  const manifestPath = path.join(dir, ".synesthesia-web-templates.sha256");
  try {
    const lines = (await fsp.readFile(manifestPath, "utf8"))
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
      if ((await fileSha256(path.join(dir, name))) !== expected.get(name)) return false;
    }
    return true;
  } catch {
    return false;
  }
}

async function verifiedTemplates() {
  return verifiedTemplatesAt(templateDir);
}

async function migrateLegacyTemplates() {
  if (await verifiedTemplates()) return false;
  if (!(await verifiedTemplatesAt(legacyTemplateDir))) return false;
  await fsp.mkdir(templateDir, { recursive: true });
  for (const name of templateNames) {
    await fsp.copyFile(path.join(legacyTemplateDir, name), path.join(templateDir, name));
  }
  await fsp.copyFile(legacyManifest, manifest);
  if (!(await verifiedTemplates())) {
    await Promise.allSettled([manifest, ...templates].map((file) => fsp.rm(file, { force: true })));
    throw new Error("migrated Synesthesia Web templates failed integrity verification");
  }
  console.log("SYNESTHESIA_NETLIFY_CACHE=MIGRATED legacy-path=1 canonical-xdg=1");
  return true;
}

module.exports = {
  onPreBuild: async ({ utils }) => {
    await utils.cache.restore(restorePaths);
    await migrateLegacyTemplates();
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
