import type { TagNode } from "@bbob/parser";

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
