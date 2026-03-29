import parse from "@bbob/parser";
import fs from "fs";
import { JSDOM } from "jsdom";
import { parseClass } from "./src/parser";


interface FieldReference {
  type: "member" | "method";
  klass: string;
  name: string;
}

function main() {
  const xml = fs.readFileSync("_NetworkTime.xml", { encoding: "utf8" });

  const dom = new JSDOM(xml, {
    contentType: "text/xml"
  })
  const classDocument = dom.window.document;
  const classData = parseClass(classDocument);

  console.log(JSON.stringify(classData, undefined, 2));
}

main();
