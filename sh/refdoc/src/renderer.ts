import type { ClassDB } from "./classdb";
import type { Class, Parameter } from "./class.types";
import type { BBCode, BBCodeToken, ConstantToken, MemberToken, MethodToken, SignalToken, UnknownToken } from "./bb.types";
import { log } from "./log";

export interface UnknownReferenceError {
  type: "UnknownReference";
  source: Class| undefined;
  class: string | undefined;
  member: string | undefined;
}

export interface UnknownTokenError {
  type: "UnknownToken";
  source: Class | undefined;
  token: BBCodeToken;
}

export type RenderError = UnknownReferenceError | UnknownTokenError;

export interface RenderSettings {
  renderPrivateMembers: boolean;
  renderPrivateMethods: boolean;
  renderPrivateConstants: boolean;
  renderPrivateSignals: boolean;
  renderPrivateClasses: boolean;

  classFilter: (classInfo: Class) => boolean;
}

export interface Renderer {
  render(targetDirectory: string): Promise<void>;
}

const defaultSettings: RenderSettings = {
  renderPrivateMethods: false,
  renderPrivateMembers: false,
  renderPrivateConstants: false,
  renderPrivateSignals: false,
  renderPrivateClasses: false,

  classFilter: () => true
}

export class MarkdownRenderer implements Renderer {
  readonly renderErrors: RenderError[] = []
  private settings: RenderSettings
  private currentClass: Class | undefined;

  constructor(
    private classDB: ClassDB,
    settings: Partial<RenderSettings> = {}
  ) {
    this.settings = { ...defaultSettings, ...settings }
  }

  async render(targetDirectory: string): Promise<void> {
    this.renderErrors.length = 0;

    log.group("Rendering files")
    for (const classInfo of this.classDB.classes) {
      if (!this.settings.classFilter(classInfo)) {
        log.print("Skipping class", classInfo.name, classInfo.srcPath)
        continue;
      }

      if (classInfo.isPrivate && !this.settings.renderPrivateClasses)
        continue;

      const file = Bun.file(targetDirectory + "/" + classInfo.name + ".md")
      this.currentClass = classInfo

      // Clear file before writing
      if (await file.exists()) 
        await file.write("")
      const sink = file.writer();

      // Overview
      sink.write(
        `# ${classInfo.name}\n\n` +
        `**Inherits:** ${await this.renderType(classInfo.inherits)}\n\n` +
        `${await this.renderBBCode(classInfo.briefDescription)}\n\n`
      )

      const classDescription = await this.renderBBCode(classInfo.description)
      if (classDescription)
        sink.write(
          `## Description\n\n` +
          `${classDescription}\n`
        )

      if (classInfo.tutorials.length) {
        sink.write("\n## Tutorials\n\n")
        for (const tutorial of classInfo.tutorials)
          if (tutorial.title)
            sink.write(`* [${tutorial.title}](${tutorial.link})\n`)
          else
            sink.write(`* <${tutorial.link}>\n`)
      }

      if (this.hasMembers(classInfo)) {
        sink.write(
          `\n## Properties\n\n` +
          `| Type | Name | Default|\n` +
          `|--|--|--|\n`
        )

        for (const member of classInfo.members) {
          if (member.isPrivate && !this.settings.renderPrivateMembers)
            continue;

          const link = `#${this.slug(member.name)}`

          const type = await this.renderType(member.type)
          const name = member.name
          const defaultValue = member.default ? `\`${member.default}\`` : ""

          sink.write(`| ${type} | [${name}](${link}) | ${defaultValue} |\n`)
        }
      }

      if (this.hasMethods(classInfo)) {
        sink.write(
          `\n## Methods\n\n` +
          `| Return Type | Name |\n` +
          `| -- | -- |\n`
        )

        for (const method of classInfo.methods) {
          if (method.isPrivate && !this.settings.renderPrivateMembers)
            continue

          const link = `#${this.slug(method.name)}`

          const type = await this.renderType(method.returnType)
          const name = method.name
          const params = await this.renderParams(method.params)
          const qualifiers = method.qualifiers ?? ""

          sink.write(`| ${type} | [${name}](${link})(${params}) ${qualifiers} |\n`)
        }
      }

      if (this.hasSignals(classInfo)) {
        sink.write(`\n## Signals\n\n`)

        for (const signal of classInfo.signals) {
          if (signal.isPrivate && !this.settings.renderPrivateSignals)
            continue;

          const name = signal.name
          const params = await this.renderParams(signal.params)
          const slug = this.slug(name)

          sink.write(
            `#### <span id="${slug}">${name} ( ${params} )</span>\n\n` +
            `${await this.renderBBCode(signal.description) || "No description provided"}\n\n` + 
            `---\n\n`
          )
        }
      }

      if (this.hasConstants(classInfo)) {
        sink.write(`\n## Constants\n`)

        for (const constant of classInfo.constants) {
          if (constant.isPrivate && !this.settings.renderPrivateConstants)
            continue;

          const slug = this.slug(constant.name)

          sink.write(
            `#### <span id="${slug}">${constant.name}</span> = \`${constant.value}\`\n\n` + 
            `${await this.renderBBCode(constant.description)}\n\n` +
            `---\n\n`
          )
        }
      }

      // Descriptions
      if (this.hasMembers(classInfo)) {
        sink.write(`\n## Property Descriptions\n\n`)

        for (const member of classInfo.members) {
          if (member.isPrivate && !this.settings.renderPrivateMembers)
            continue

          const name = member.name
          const type = await this.renderType(member.type)
          const defaultSuffix = member.default ? `= \`${member.default}\`` : ""
          const description = await this.renderBBCode(member.description) || "No description provided."
          const slug = this.slug(member.name)

          sink.write(
            `#### <span id="${slug}">${type} ${name}</span> ${defaultSuffix}\n` + 
            `${description}\n\n` +
            `---\n\n`
          )
        }
      }

      if (this.hasMethods(classInfo)) {
        sink.write(`\n## Method Descriptions\n\n`)

        for (const method of classInfo.methods) {
          if (method.isPrivate && !this.settings.renderPrivateMethods)
            continue

          const type = await this.renderType(method.returnType)
          const name = method.name
          const params = await this.renderParams(method.params)
          const qualifiers = method.qualifiers ?? ""
          const description = method.description
          const slug = this.slug(name)

          sink.write(
            `#### <span id="${slug}">${type} ${name} ( ${params} ) ${qualifiers}</span>\n\n` + 
            `${await this.renderBBCode(description) || "No description provided."}\n\n` +
            `---\n\n`
          )
        }
      }

      sink.end()

      log.print(`Rendered ${file.name}`)
    }

    log.endgroup()

    if (this.renderErrors.length > 0) {
      log.group("Rendering errors")

      // Print errors
      for (const error of this.renderErrors) {
        const file = error.source?.srcPath ?? error.source?.name ?? ""

        if (error.type === "UnknownReference")
          log.errorInFile(file, `Unknown reference to ${error.class ?? "local"}.${error.member}`)
        if (error.type === "UnknownToken")
          if (error.token.type === "?")
            log.errorInFile(file, `Encountered unknown token ${error.token.tag.toString()}`)
          else
            log.errorInFile(file, `Encountered unknown token:\n${JSON.stringify(error.token)}`)
      }

      log.endgroup()
    }
  }

  private async renderBBCode(tokens: BBCode | undefined): Promise<string> {
    if (tokens === undefined) return ""

    const result = []
    for (const token of tokens) {
      if (token.type === "string")
        result.push(token.text)
      else if(token.type === "br")
        result.push("  \n")
      else if(token.type === "i")
        result.push(`_${await this.renderBBCode(token.content)}_`)
      else if(token.type === "b")
        result.push(`**${await this.renderBBCode(token.content)}**`)
      else if(token.type === "u")
        result.push(`_${await this.renderBBCode(token.content)}_`)
      else if(token.type === "s")
        result.push(`~~${await this.renderBBCode(token.content)}~~`)
      else if(token.type === "url") {
        if (token.content !== undefined)
          result.push(`[${await this.renderBBCode(token.content)}](${token.link})`)
        else
          result.push(`<${token.link}>`)
      }
      else if(token.type === "code")
        result.push(`\`${token.code}\``)
      else if(token.type === "codeblock")
        result.push("\n\n```gd\n" + token.code + "\n```\n\n")
      else if(token.type === "method")
        result.push(await this.renderMethodReference(token))
      else if (token.type === "param")
        result.push(`\`${token.name}\``)
      else if(token.type === "member")
        result.push(await this.renderMemberReference(token))
      else if(token.type === "constant")
        result.push(await this.renderConstantReference(token))
      else if(token.type === "signal")
        result.push(await this.renderSignalReference(token))
      else if(token.type === "?") {
        const className = token.tag.tag
        const localClass = this.classDB.findByName(className)
        const externalLink = localClass ? undefined : await this.classDB.lookupExternal(className)
        if (localClass) {
          // It's a link to a local class
          result.push(`[${localClass?.name}](./${localClass.name}.md)`)
        } else if (externalLink) {
          result.push(`[${className}](${externalLink})`)
        } else {
          this.pushUnknown(token, result)
        }
      } else {
        this.pushUnknown(token, result)
      }
    }

    return result.join("")
  }

  private pushUnknown(token: BBCodeToken, result: string[]) {
    result.push(
      "\n\n```\n" +
      JSON.stringify(token, undefined, 2) +
      "\n```\n\n"
    )

    this.pushError({ type: "UnknownToken", token, source: undefined })
  }

  private slug(text: string): string {
    return text.replace(/[^\d\w]/g, "-").toLowerCase()
  }

  private hasMembers(classInfo: Class): boolean {
    return this.settings.renderPrivateMembers
      ? classInfo.members.length > 0
      : classInfo.members.some(s => !s.isPrivate)
  }

  private hasMethods(classInfo: Class): boolean {
    return this.settings.renderPrivateMethods
      ? classInfo.methods.length > 0
      : classInfo.methods.some(s => !s.isPrivate)
  }

  private hasSignals(classInfo: Class): boolean {
    return this.settings.renderPrivateSignals
      ? classInfo.signals.length > 0
      : classInfo.signals.some(s => !s.isPrivate)
  }

  private hasConstants(classInfo: Class): boolean {
    return this.settings.renderPrivateConstants
      ? classInfo.constants.length > 0
      : classInfo.constants.some(c => !c.isPrivate)
  }

  private async getTypeLink(type: string): Promise<string | undefined> {
    if (type.endsWith("[]"))
      return this.getTypeLink(type.slice(0, type.length - 2))

    const localClass = this.classDB.findByName(type)
    if (localClass)
      return `./${localClass.name}.md`
    else
      return this.classDB.lookupExternal(type)
  }

  private async renderParams(params: Parameter[]): Promise<string> {
    const result = []
    for (const param of params) {
      const type = await this.renderType(param.type)
      const name = param.name

      result.push(`${type} ${name}`)
    }

    return result.join(', ')
  }

  private async renderType(type: string): Promise<string> {
    // `void` has no docs, and that's fine
    if (type == "void")
      return type

    const typeLink = await this.getTypeLink(type)

    if (!typeLink) {
      this.pushError({ type: "UnknownReference", source: undefined, class: type, member: undefined})
      return type
    }

    return `[${type}](${typeLink})`
  }

  private async renderMethodReference(method: MethodToken): Promise<string> {
    return this.renderReference(method.class, method.name, method.name + "()")
  }

  private async renderMemberReference(member: MemberToken): Promise<string> {
    return this.renderReference(member.class, member.name)
  }

  private async renderConstantReference(constant: ConstantToken): Promise<string> {
    return this.renderReference(constant.class, constant.name)
  }

  private async renderSignalReference(signal: SignalToken): Promise<string> {
    return this.renderReference(signal.class, signal.name, signal.name + "()")
  }

  private async renderReference(type: string | undefined, name: string, displayName: string = name): Promise<string> {
    const slug = this.slug(name)
    if (type === undefined)
      return `[${displayName}](#${slug})`

    const classInfo = this.classDB.findByName(type)
    if (classInfo !== undefined) {
      const classLink = `./${classInfo?.name}.md`
      return `[${classInfo?.name}.${displayName}](${classLink}#${slug})`
    }

    const externalLink = await this.classDB.lookupExternal(type)
    if (externalLink !== undefined) {
      return `[${type}.${displayName}](${externalLink})`
    }

    this.pushError({ type: "UnknownReference", source: undefined, class: type, member: name })
    return `*${type}.${displayName}*`
  }

  private pushError(error: RenderError) {
    error.source = this.currentClass;
    this.renderErrors.push(error)
  }
}
