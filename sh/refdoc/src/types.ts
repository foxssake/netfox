
export interface Class {
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

export interface Tutorial {
  title: string | undefined;
  link: string;
}

export interface Method {
  name: string;
  qualifiers: string | undefined;
  returnType: string;
  description: string;
  params: Parameter[];
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
  description: string;
}

export interface Constant {
  name: string;
  value: string;
  enum: string | undefined;
  description: string;
}

export interface Signal {
  name: string;
  description: string;
  params: Parameter[];
}
