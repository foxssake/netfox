import { ClassDB } from "./src/classdb";

async function main() {
  const dir = "../../apidocs/";
  const src = "../../";

  const classdb = (await ClassDB.fromDirectory(dir)).onlyNamedClasses();
  await classdb.exploreLocations(src);
  classdb.classes = classdb.classes.filter(c => c.srcPath?.startsWith("addons/netfox"))

  console.log(JSON.stringify(classdb.classes))
}

main();
