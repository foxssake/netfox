import { JSDOM } from "jsdom";
import type { Class } from "./types";
import { isFileBasedName, parseClass } from "./parser";
import { readdir } from "node:fs/promises";

export class ClassDB {
  classes: Class[] = [];

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
}
