import parse, { TagNode } from "@bbob/parser";

export interface StringToken {
  type: "string";
  text: string;
}

export interface LineBreakToken {
  type: "br";
}

export interface ItalicToken {
  type: "i";
  content: BBCode;
}

export interface BoldToken {
  type: "b";
  content: BBCode;
}

export interface UnderlineToken {
  type: "u";
  content: BBCode;
}

export interface StrikeThroughToken {
  type: "s";
  content: BBCode;
}

export interface UrlToken {
  type: "url";
  link: string;
  content: BBCode | undefined;
}

export interface CodeToken {
  type: "code";
  code: string;
}

export interface CodeBlockToken {
  type: "codeblock";
  code: string;
}

export interface MethodToken {
  type: "method";
  class: string | undefined;
  name: string;
}

export interface ParamToken {
  type: "param",
  name: string
}

export interface MemberToken {
  type: "member";
  class: string | undefined;
  name: string;
}

export interface ConstantToken {
  type: "constant";
  class: string | undefined;
  name: string;
}

export interface SignalToken {
  type: "signal";
  class: string | undefined;
  name: string;
}

export interface UnknownToken {
  type: "?";
  tag: TagNode
}

export type BBCodeToken = StringToken | LineBreakToken | 
  ItalicToken | BoldToken | UnderlineToken | StrikeThroughToken |
  UrlToken | CodeToken | CodeBlockToken |
  MethodToken | ParamToken | MemberToken | ConstantToken | SignalToken |
  UnknownToken;

export type BBCode = BBCodeToken[];

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
    else if (node.tag === "code") tokens.push({ type: "code", code: node.content?.toString() ?? "" })
    else if (node.tag === "codeblock") tokens.push({ type: "codeblock", code: node.content?.toString() ?? "" })
    else if (node.tag === "url") {
      tokens.push({ type: "url", link: node.content?.toString() ?? "", content: undefined })
    } else if (node.tag.startsWith("url=")) {
      const link = node.tag.split("=").at(1)!!
      tokens.push({ type: "url", link, content: parseAst(node.content as TagNode[])})
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
