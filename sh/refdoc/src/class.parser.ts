import { parseBBCode } from "./bb.parser";
import type { Class, Constant, Member, Method, Parameter, Signal, Tutorial } from "./class.types";

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

  // TODO: Enable `undefined` values to exist
  const briefDescription = parseBBCode(classDocument.querySelector("brief_description")?.textContent?.trim() ?? "");
  const description = parseBBCode(classDocument.querySelector("description")?.textContent?.trim() ?? "");

  const tutorials: Tutorial[] = [...classDocument.querySelectorAll("tutorials>link")].map(e => ({
    title: e.getAttribute("title") ?? undefined,
    link: e.parentNode?.textContent?.trim()!! // TODO: This will break with multiple tutorials
  }))

  const methods: Method[] = [...classDocument.querySelectorAll("methods>method")].map(e => ({
    name: e.getAttribute("name")!!,
    qualifiers: e.getAttribute("qualifiers") ?? undefined,
    description: parseBBCode(e.querySelector("description")?.textContent?.trim()!!),
    returnType: e.querySelector("return")?.getAttribute("type")!!,
    params: parseParams(e),
    isPrivate: e.getAttribute("name")?.startsWith("_") === true
  }));

  const members: Member[] = [...classDocument.querySelectorAll("members>member")].map(e => ({
    name: e.getAttribute("name")!!,
    type: e.getAttribute("type")!!,
    setter: e.getAttribute("setter") ?? undefined,
    getter: e.getAttribute("getter") ?? undefined,
    default: e.getAttribute("default") ?? undefined,
    description: parseBBCode(e.textContent.trim()),
    isPrivate: e.getAttribute("name")?.startsWith("_") === true
  }));

  const constants: Constant[] = [...classDocument.querySelectorAll("constants>constant")].map(e => ({
    name: e.getAttribute("name")!!,
    value: e.getAttribute("value")!!,
    enum: e.getAttribute("enum") ?? undefined,
    description: parseBBCode(e.textContent.trim()),
    isPrivate: e.getAttribute("name")?.startsWith("_") === true
  }));

  const signals: Signal[] = [...classDocument.querySelectorAll("signals>signal")].map(e => ({
    name: e.getAttribute("name")!!,
    description: parseBBCode(e.querySelector("description")?.textContent?.trim()!!),
    params: parseParams(e),
    isPrivate: e.getAttribute("name")?.startsWith("_") === true
  }));

  return {
    name: className,
    inherits: classInherits,
    isPrivate: isPrivateClass(className),

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

function isPrivateClass(name: string): boolean {
  if (isFileBasedName(name))
    return true

  if (name.includes("."))
    // Inner class
    return name.split(".").at(-1)?.startsWith("_") !== false

  return name.startsWith("_")
}
