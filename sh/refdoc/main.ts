import { ClassDB } from "./src/classdb";
import { MarkdownRenderer } from "./src/renderer";

const excludedClasses = new Set([
  "NetworkClocks.SteppingClock",
  "NetworkClocks.SystemClock",
  "_NetworkSimulator.QueueEntry",
  "_PacketHandshake.HandshakeStatus"
])

async function main(args: string[]): Promise<number> {
  const dir = args.at(0) ?? "apidocs/";
  const src = args.at(1) ?? "./";
  const out = args.at(2) ?? "out/"

  const classdb = (await ClassDB.fromDirectory(dir)).onlyNamedClasses();
  await classdb.exploreLocations(src);
  // classdb.classes = classdb.classes
  //   .filter(c => c.srcPath?.startsWith("addons/netfox") === true)
  //   .filter(c => !c.isPrivate)

  await Bun.file("classdb.json").write(JSON.stringify(classdb.classes, undefined, 2))

  // const renderer = new MarkdownRenderer(classdb, false, false, c => c.srcPath?.startsWith("addons/netfox") === true);
  const renderer = new MarkdownRenderer(classdb, {
    classFilter: classInfo => 
      classInfo.srcPath?.startsWith("addons/netfox") === true &&
      !excludedClasses.has(classInfo.name)
  });
  await renderer.render(out);

  return renderer.renderErrors.length == 0
    ? 0
    : 1
}

process.exitCode = await main(process.argv.slice(2));
