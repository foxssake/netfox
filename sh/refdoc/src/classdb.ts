import { JSDOM } from "jsdom";
import type { Class } from "./class.types";
import { isFileBasedName, parseClass } from "./class.parser";
import { readdir } from "node:fs/promises";
import { log } from './log'

export class ClassDB {
  classes: Class[] = [];

  private externalLookups: Map<string, string | undefined> = new Map();

  static async fromDirectory(path: string): Promise<ClassDB> {
    log.group(`Loading docs from ${path}`)
    const db = new ClassDB();

    const files = await readdir(path, { recursive: true })
    for (const file of files) {
      if (file.endsWith(".xml")) {
        await db.ingestFile(path + "/" + file)
        log.print(`Ingested ${file}`)
      }
    }
    log.endgroup();

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
  }

  async exploreLocations(root: string): Promise<void> {
    log.group("Exploring file data")

    const files = await readdir(root, { recursive: true });

    const classNamePattern = /class_name\s+([^\s]+)/;
    const privateClassPattern = /^\s*#\s*@private\s+class\s*$/m
    const publicClassPattern = /^\s*#\s*@public\s+class\s*$/m

    for (const file of files) {
      if (!file.endsWith(".gd")) continue;

      const fileHandle = Bun.file(root + "/" + file);
      if ((await fileHandle.stat()).isDirectory()) continue

      const script = await Bun.file(root + "/" + file).text()
      const hit = classNamePattern.exec(script);
      const classInfo = (hit !== null && hit.length >= 2)
        ? this.findByName(hit.at(1) ?? "")
        : undefined;

      if (classInfo) {
        classInfo.srcPath = file

        if (privateClassPattern.test(script))
          classInfo.isPrivate = true
        if (publicClassPattern.test(script))
          classInfo.isPrivate = false
      }
    
      log.print(`Explored ${file}`)
    }

    log.endgroup()
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
    log.print(`Checking ${name} at ${address}...`)

    const response = await fetch(address);

    if (response.ok) {
      log.print(`\tFound ${name} as external!`)
      this.externalLookups.set(name, address)
      return address
    } else {
      log.print(`\tClass ${name} is not known`)
      this.externalLookups.set(name, undefined)
      return undefined
    }
  }
}
