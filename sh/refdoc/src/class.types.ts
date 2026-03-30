import type { BBCode } from "./bb.types";

export interface Class {
  name: string;
  inherits: string;
  isPrivate: boolean;

  xmlPath: string | undefined;
  srcPath: string| undefined;

  briefDescription: BBCode | undefined;
  description: BBCode | undefined;

  tutorials: Tutorial[];

  methods: Method[];
  members: Member[];
  constants: Constant[];
  signals: Signal[];
  // TODO: Enumerations
}

export interface Tutorial {
  title: string | undefined;
  link: string;
}

export interface Method {
  name: string;
  qualifiers: string | undefined;
  returnType: string;
  description: BBCode;
  params: Parameter[];
  isPrivate: boolean;
}

export interface Parameter {
  index: number;
  name: string;
  type: string;
}

export interface Member {
  name: string;
  type: string;
  setter: string | undefined;
  getter: string | undefined;
  default: string | undefined;
  description: BBCode;
  isPrivate: boolean;
}

export interface Constant {
  name: string;
  value: string;
  enum: string | undefined;
  description: BBCode;
  isPrivate: boolean;
}

export interface Signal {
  name: string;
  description: BBCode;
  params: Parameter[];
  isPrivate: boolean;
}
