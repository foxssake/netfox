import parse, { TagNode } from "@bbob/parser";
import type { BBCodeToken, StringToken } from "./bb.types";

export function parseBBCode(bbCode: string): BBCodeToken[] {
  return parseAst(parse(bbCode));
}

function parseAst(ast: TagNode[]): BBCodeToken[] {
  const tokens: BBCodeToken[] = [];

  const localMethodPattern = /^method\s+([^.]+)$/
  const classMethodPattern = /^method\s+([^.]+)\.([^.]+)$/

  const localMemberPattern = /^member\s+([^.]+)$/
  const classMemberPattern = /^member\s+([^.]+)\.([^.]+)$/

  const localConstantPattern = /^constant\s+([^.]+)$/
  const classConstantPattern = /^constant\s+([^.]+)\.([^.]+)$/

  const localSignalPattern = /^signal\s+([^.]+)$/
  const classSignalPattern = /^signal\s+([^.]+)\.([^.]+)$/

  const paramPattern = /^param\s+(.*)$/

  for (const node of ast) {
    if (typeof node === "string")
      if (tokens.at(-1)?.type === "string")
        (tokens.at(-1)!! as StringToken).text += node
      else
        tokens.push({
          type: "string",
          text: node
        })
    else if (node.tag === "br")
      tokens.push({
      type: "br"
    })
    else if (node.tag == "lb") tokens.push({ type: "string", text: "[" }) 
    else if (node.tag == "rb") tokens.push({ type: "string", text: "]" }) 
    else if (node.tag === "i") tokens.push({ type: "i", content: parseAst(node.content as TagNode[]) })
    else if (node.tag === "b") tokens.push({ type: "b", content: parseAst(node.content as TagNode[]) })
    else if (node.tag === "u") tokens.push({ type: "u", content: parseAst(node.content as TagNode[]) })
    else if (node.tag === "s") tokens.push({ type: "s", content: parseAst(node.content as TagNode[]) })
    else if (node.tag === "code") tokens.push({ type: "code", code: (node.content as TagNode[] ?? []).map(i => i + "").join("") })
    else if (node.tag === "codeblock") tokens.push({ type: "codeblock", code: (node.content as TagNode[] ?? []).map(i => i + "").join("") })
    else if (node.tag === "url") {
      const attrs = Object.values(node.attrs) as string[]
      if (attrs.length == 1)
        tokens.push({ type: "url", link: attrs[0], content: parseAst(node.content as TagNode[])})
      else
        tokens.push({ type: "url", link: (node.content as TagNode[] ?? []).map(i => i + "").join(""), content: undefined })
    }
    else if (classMethodPattern.test(node.tag)) {
      const hit = classMethodPattern.exec(node.tag)!!
      tokens.push({ type: "method", class: hit[1]!!, name: hit[2]!!})
    } else if (localMethodPattern.test(node.tag)) {
      const hit = localMethodPattern.exec(node.tag)!!
      tokens.push({ type: "method", class: undefined, name: hit[1]!!})
    }
    else if (classMemberPattern.test(node.tag)) {
      const hit = classMemberPattern.exec(node.tag)!!
      tokens.push({ type: "member", class: hit[1]!!, name: hit[2]!!})
    } else if (localMemberPattern.test(node.tag)) {
      const hit = localMemberPattern.exec(node.tag)!!
      tokens.push({ type: "member", class: undefined, name: hit[1]!!})
    } else if (classConstantPattern.test(node.tag)) {
      const hit = classConstantPattern.exec(node.tag)!!
      tokens.push({ type: "constant", class: hit[1]!!, name: hit[2]!!})
    } else if (localConstantPattern.test(node.tag)) {
      const hit = localConstantPattern.exec(node.tag)!!
      tokens.push({ type: "constant", class: undefined, name: hit[1]!!})
    } else if (classSignalPattern.test(node.tag)) {
      const hit = classSignalPattern.exec(node.tag)!!
      tokens.push({ type: "signal", class: hit[1]!!, name: hit[2]!!})
    } else if (localSignalPattern.test(node.tag)) {
      const hit = localSignalPattern.exec(node.tag)!!
      tokens.push({ type: "signal", class: undefined, name: hit[1]!!})
    } else if (paramPattern.test(node.tag)) {
      const hit = paramPattern.exec(node.tag)
      tokens.push({ type: "param", name: hit?.at(1)!! })
    } else {
      tokens.push({ type: "?", tag: node })
    }
  }

  return tokens;
}
