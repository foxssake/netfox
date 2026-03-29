import type { Class, Constant, Member, Method, Parameter, Signal, Tutorial } from "./types";

function parseParams(root: Element): Parameter[] {
  return [...root.querySelectorAll("param" as string)].map(e => ({
    name: e.getAttribute("name")!!,
    type: e.getAttribute("type")!!,
    index: parseInt(e.getAttribute("index")!!)
  })).toSorted((a, b) => a.index - b.index);
}

export function parseClass(classDocument: Document): Class {
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

  return {
    name: className,
    inherits: classInherits,

    xmlPath: undefined,
    srcPath: undefined,

    briefDescription,
    description,

    tutorials,

    methods,
    members,
    constants,
    signals
  }
}

export function isFileBasedName(className: string): boolean {
  return className.includes(".gd") || className.includes("/") || className.includes("\\");
}
