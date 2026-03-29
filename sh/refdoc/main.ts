import parse from "@bbob/parser";
import fs from "fs";
import { JSDOM } from "jsdom";

interface Class {
  name: string;
  inherits: string;
  path: string | undefined;

  briefDescription: string | undefined;
  description: string | undefined;

  tutorials: Tutorial[];

  methods: Method[];
  members: Member[];
  constants: Constant[];
  signals: Signal[];
}

interface Tutorial {
  title: string | undefined;
  link: string;
}

interface Method {
  name: string;
  qualifiers: string | undefined;
  returnType: string;
  description: string;
  params: Parameter[];
}

interface Parameter {
  index: number;
  name: string;
  type: string;
}

interface Member {
  name: string;
  type: string;
  setter: string | undefined;
  getter: string | undefined;
  default: string | undefined;
  description: string;
}

interface Constant {
  name: string;
  value: string;
  enum: string | undefined;
  description: string;
}

interface Signal {
  name: string;
  description: string;
  params: Parameter[];
}

interface FieldReference {
  type: "member" | "method";
  klass: string;
  name: string;
}

function parseParams(root: Element): Parameter[] {
  return [...root.querySelectorAll("param")].map(e => ({
    name: e.getAttribute("name")!!,
    type: e.getAttribute("type")!!,
    index: parseInt(e.getAttribute("index")!!)
  })).toSorted((a, b) => a.index - b.index);
}

function main() {
  const xml = fs.readFileSync("_NetworkTime.xml", { encoding: "utf8" });

  const dom = new JSDOM(xml, {
    contentType: "text/xml"
  })
  const classDocument = dom.window.document;

  const classTag = classDocument.querySelector("class");
  const className = classTag?.getAttribute("name")!!
  const classInherits = classTag?.getAttribute("inherits")!!

  const briefDescription = classDocument.querySelector("brief_description")?.textContent?.trim();
  const description = classDocument.querySelector("description")?.textContent?.trim();

  const tutorials: Tutorial[] = [...classDocument.querySelectorAll("tutorials>link")].map(e => ({
    title: e.getAttribute("title") ?? undefined,
    link: e.textContent
  }))

  const methods: Method[] = [...classDocument.querySelectorAll("methods>method")].map(e => ({
    name: e.getAttribute("name")!!,
    qualifiers: e.getAttribute("qualifiers") ?? undefined,
    description: e.querySelector("description")?.textContent?.trim()!!,
    returnType: e.querySelector("return")?.getAttribute("type")!!,
    params: parseParams(e)
  }));

  const members: Member[] = [...classDocument.querySelectorAll("members>member")].map(e => ({
    name: e.getAttribute("name")!!,
    type: e.getAttribute("type")!!,
    setter: e.getAttribute("setter") ?? undefined,
    getter: e.getAttribute("getter") ?? undefined,
    default: e.getAttribute("default") ?? undefined,
    description: e.textContent.trim()
  }));

  const constants: Constant[] = [...classDocument.querySelectorAll("constants>constant")].map(e => ({
    name: e.getAttribute("name")!!,
    value: e.getAttribute("value")!!,
    enum: e.getAttribute("enum") ?? undefined,
    description: e.textContent.trim()
  }));

  const signals: Signal[] = [...classDocument.querySelectorAll("signals>signal")].map(e => ({
    name: e.getAttribute("name")!!,
    description: e.querySelector("description")?.textContent?.trim()!!,
    params: parseParams(e)
  }));

  const classData: Class = {
    name: className,
    inherits: classInherits,

    briefDescription,
    description,

    tutorials,

    methods,
    members,
    constants,
    signals
  }

  console.log(JSON.stringify(classData, undefined, 2));
  return;

  const input = "NetfoxLoggers implement distinct log levels. These can be used to filter which messages are actually emitted. All messages are output using [method @GlobalScope.print]. Warnings and errors are also pushed to the debug panel, using [method @GlobalScope.push_warning] and [method @GlobalScope.push_error] respectively, if [member push_to_debugger] is enabled. [br][br]Every logger has a name, and belongs to a module. Logging level can be overridden per module, using [member module_log_level]. [br][br]Loggers also support tags. Tags can be used to provide extra pieces of information that are logged with each message. Some tags are provided by netfox. Additional tags can be added using [method register_tag].";

  const ast = parse(input);
  const tags = [] as Array<FieldReference>;
  for (const node of ast) {
    if (typeof node === "string") continue;

    const tag = node.tag as string;
    if (tag.startsWith("member ")) {
      tags.push({
        type: "member",
        klass: "current",
        name: tag.slice("member ".length)
      })
    } else if (tag.startsWith("method ")) {
      const body = tag.slice("method ".length)
      const [klass, name] = body.includes(".")
        ? body.split(".")
        : ["current", body]
      tags.push({
        type: "method",
        klass,
        name
      })
    }
  }

  console.log(tags)
}

main();
