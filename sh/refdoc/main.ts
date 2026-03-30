import { ClassDB } from "./src/classdb";
import { MarkdownRenderer } from "./src/renderer";

async function main() {
  const dir = "../../apidocs/";
  const src = "../../";

  const classdb = (await ClassDB.fromDirectory(dir)).onlyNamedClasses();

  await classdb.exploreLocations(src);

  await Bun.file("classdb.json").write(JSON.stringify(classdb.classes, undefined, 2))

  // const renderer = new MarkdownRenderer(classdb, false, false, c => c.srcPath?.startsWith("addons/netfox") === true);
  const renderer = new MarkdownRenderer(classdb);
  renderer.render("out/");
}

main();
