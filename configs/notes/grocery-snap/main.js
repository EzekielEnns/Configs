// Grocery snap: a cart button that opens the camera, sends the photo to Bolt on the desktop
// (llama-swap over Tailscale) and opens Shared/Groceries/<date>.md with a checkbox per item.
// Same prompt, schema and note format as configs/notes/groceries.py, the desktop watcher. If
// the desktop can't be reached, the photo goes to the watcher's Inbox/Groceries/ instead and
// the note appears when the desktop is back. Plain CommonJS, no build step.
const { Plugin, Notice, PluginSettingTab, Setting, requestUrl, arrayBufferToBase64, moment } = require("obsidian");

const DEFAULTS = { api: "http://100.64.96.125:8080/v1", model: "bolt" };
const OUT = "Shared/Groceries";
const INBOX = "Inbox/Groceries";
const TIMEOUT = 90_000; // a cold model load included
const MAX_SIDE = 1600;

const PROMPT = `This is a photo of a handwritten grocery list. List every item on it, in order, as written.
- One entry per item: when a line names several things separated by commas, give each its own entry.
- Keep quantities and notes that belong to an item with it ("2 milk", "eggs (dozen)").
- Include every column, and small additions squeezed between or above lines.
- Skip headings, dates and crossed-out items.
- If you can't read an item with confidence, give your best guess and set unsure to true.
- If the photo isn't a list, return no items.`;
// Bolt sometimes slips into its thinking channel even with thinking off and loops until the
// token limit, leaving no answer: answer directly first, then once more with thinking allowed.
const SYSTEM = "Answer directly with the JSON. Do not think out loud.";

const SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: { text: { type: "string" }, unsure: { type: "boolean" } },
        required: ["text", "unsure"],
      },
    },
  },
  required: ["items"],
};

module.exports = class GrocerySnap extends Plugin {
  async onload() {
    this.settings = Object.assign({}, DEFAULTS, await this.loadData());
    this.addRibbonIcon("shopping-cart", "Snap grocery list", () => this.snap());
    this.addCommand({ id: "snap", name: "Snap grocery list", callback: () => this.snap() });
    this.addSettingTab(new SettingsTab(this.app, this));
  }

  snap() {
    // A file input with capture opens the camera on a phone, a file picker on a computer.
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.setAttribute("capture", "environment");
    input.onchange = () => input.files && input.files[0] && this.process(input.files[0]);
    input.click();
  }

  async process(file) {
    const taken = moment();
    const notice = new Notice("Reading the list…", 0);
    let jpeg;
    try {
      jpeg = await upright(file);
    } catch (e) {
      notice.hide();
      new Notice(`Couldn't open the photo: ${e.message}`);
      return;
    }

    let items;
    try {
      items = await withTimeout(this.read(jpeg), TIMEOUT);
    } catch (e) {
      // Desktop off, asleep or unreachable: let the watcher do it when it's back.
      await this.ensureFolder(INBOX);
      await this.app.vault.createBinary(await this.free(`${INBOX}/${taken.format("YYYY-MM-DD-HHmmss")}.jpg`), jpeg);
      notice.hide();
      new Notice("The desktop didn't answer. Your list will show up in Shared/Groceries when it's back.", 8000);
      console.warn("grocery-snap:", e);
      return;
    }

    await this.ensureFolder(`${OUT}/attachments`);
    const attachment = await this.free(`${OUT}/attachments/${taken.format("YYYY-MM-DD-HHmmss")}.jpg`);
    await this.app.vault.createBinary(attachment, jpeg);
    const name = attachment.split("/").pop();
    const lines = ["---", "tags:", "  - groceries", `created: ${taken.format("YYYY-MM-DDTHH:mm")}`,
      `photo: "[[${name}]]"`, "---", ""];
    for (const i of items) lines.push(`- [ ] ${i.text.trim()}${i.unsure ? " (?)" : ""}`);
    if (items.length === 0) lines.push("_No items read from the photo; check it below._");
    lines.push("", `![[${name}]]`, "");
    const note = await this.app.vault.create(await this.free(`${OUT}/${taken.format("YYYY-MM-DD")}.md`), lines.join("\n"));
    notice.hide();
    await this.app.workspace.getLeaf(false).openFile(note);
  }

  async read(jpeg) {
    const user = { role: "user", content: [
      { type: "image_url", image_url: { url: `data:image/jpeg;base64,${arrayBufferToBase64(jpeg)}` } },
      { type: "text", text: PROMPT },
    ] };
    for (const think of [false, true]) {
      const res = await requestUrl({
        url: `${this.settings.api.replace(/\/$/, "")}/chat/completions`,
        method: "POST",
        contentType: "application/json",
        body: JSON.stringify({
          model: this.settings.model,
          temperature: 0.2,
          max_tokens: 6144,
          chat_template_kwargs: { enable_thinking: think },
          response_format: { type: "json_schema", json_schema: { name: "groceries", schema: SCHEMA } },
          messages: think ? [user] : [{ role: "system", content: SYSTEM }, user],
        }),
      });
      try {
        const items = JSON.parse(res.json.choices[0].message.content).items;
        return items.filter((i) => i.text.trim());
      } catch (e) {
        if (think) throw e;
      }
    }
  }

  async ensureFolder(path) {
    if (!this.app.vault.getAbstractFileByPath(path)) await this.app.vault.createFolder(path);
  }

  /** path, or path with -2, -3, ... before the extension if it's taken. */
  async free(path) {
    const dot = path.lastIndexOf(".");
    let n = 1, candidate = path;
    while (this.app.vault.getAbstractFileByPath(candidate)) {
      n += 1;
      candidate = `${path.slice(0, dot)}-${n}${path.slice(dot)}`;
    }
    return candidate;
  }
};

/** The photo as an upright JPEG no larger than MAX_SIDE: createImageBitmap applies the EXIF
 * rotation phones store instead of turning the pixels. */
async function upright(file) {
  const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();
  const blob = await new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("couldn't encode the photo"))), "image/jpeg", 0.9));
  return blob.arrayBuffer();
}

function withTimeout(promise, ms) {
  return Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error("timed out")), ms))]);
}

class SettingsTab extends PluginSettingTab {
  constructor(app, plugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display() {
    this.containerEl.empty();
    new Setting(this.containerEl).setName("Model endpoint")
      .setDesc("OpenAI-compatible URL on the desktop (Tailscale).")
      .addText((t) => t.setValue(this.plugin.settings.api).onChange(async (v) => {
        this.plugin.settings.api = v.trim();
        await this.plugin.saveData(this.plugin.settings);
      }));
    new Setting(this.containerEl).setName("Model")
      .addText((t) => t.setValue(this.plugin.settings.model).onChange(async (v) => {
        this.plugin.settings.model = v.trim();
        await this.plugin.saveData(this.plugin.settings);
      }));
  }
}
