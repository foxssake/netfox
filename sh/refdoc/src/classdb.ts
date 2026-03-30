import { JSDOM } from "jsdom";
import type { Class } from "./class.types";
import { isFileBasedName, parseClass } from "./class.parser";
import { readdir } from "node:fs/promises";
import { sleep } from "bun";

export class ClassDB {
  classes: Class[] = [];

  private externalLookups: Map<string, string | undefined> = new Map();

  static async fromDirectory(path: string): Promise<ClassDB> {
    const db = new ClassDB();

    const files = await readdir(path, { recursive: true })
    for (const file of files) {
      if (file.endsWith(".xml"))
        await db.ingestFile(path + "/" + file)
    }

    return db;
  }

  ingest(xml: string, path?: string) {
    const dom = new JSDOM(xml)
    const classInfo = parseClass(dom.window.document);
    classInfo.xmlPath = path

    this.classes.push(classInfo)
  }

  async ingestFile(path: string) {
    this.ingest(await Bun.file(path).text(), path)
    console.log(`Ingested ${path}`)
  }

  async exploreLocations(root: string): Promise<void> {
    const files = await readdir(root, { recursive: true });

    const pattern = /class_name\s+([^\s]+)/g;
    for (const file of files) {
      if (!file.endsWith(".gd")) continue;

      const fileHandle = Bun.file(root + "/" + file);
      if ((await fileHandle.stat()).isDirectory()) continue

      const script = await Bun.file(root + "/" + file).text()
      const hit = pattern.exec(script);
      const classInfo = (hit !== null && hit.length >= 2)
        ? this.findByName(hit.at(1) ?? "")
        : undefined;

      if (classInfo)
        classInfo.srcPath = file

      console.log(`Explored ${file}`)
    }
  }

  onlyNamedClasses(): ClassDB {
    this.classes = this.classes.filter(c => !isFileBasedName(c.name))
    return this
  }

  findByName(name: string): Class | undefined {
    // TODO: Cache classes by name
    return this.classes.find(c => c.name === name);
  }

  hasByName(name: string): boolean {
    return this.findByName(name) !== undefined
  }

  async lookupExternal(name: string): Promise<string | undefined> {
    if (this.externalLookups.has(name))
      return this.externalLookups.get(name);

    const address = `https://docs.godotengine.org/en/4.1/classes/class_${name.toLowerCase()}.html`
    console.log(`Checking ${name} at ${address}...`)

    const response = await fetch(address);
    // await sleep(200)

    if (response.ok) {
      console.log(`Found ${name} as external!`)
      this.externalLookups.set(name, address)
      return address
    } else {
      console.log(`Class ${name} is not known`)
      this.externalLookups.set(name, undefined)
      return undefined
    }
  }
}
