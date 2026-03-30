import type { ClassDB } from "./classdb";
import type { Class, Parameter } from "./class.types";
import type { BBCode, BBCodeToken, ConstantToken, MemberToken, MethodToken, SignalToken } from "./bb.types";

export interface Renderer {
  render(targetDirectory: string): Promise<void>;
}

export class MarkdownRenderer implements Renderer {
  constructor(
    private classDB: ClassDB,
    private renderPrivateMembers: boolean = false,
    private renderPrivateMethods: boolean = false,
    private classFilter: (classInfo: Class) => boolean = () => true
  ) {}

  async render(targetDirectory: string): Promise<void> {
    for (const classInfo of this.classDB.classes) {
      if (!this.classFilter(classInfo)) {
        console.log("Skipping class", classInfo.name, classInfo.srcPath)
        continue;
      }

      const file = Bun.file(targetDirectory + "/" + classInfo.name + ".md")

      // Clear file before writing
      if (await file.exists()) 
        await file.write("")
      const sink = file.writer();

      // Overview
      sink.write(
        `# ${classInfo.name}\n\n` +
        `**Inherits:** ${await this.renderType(classInfo.inherits)}\n\n` +
        `${await this.renderBBCode(classInfo.briefDescription)}\n\n` + 
        `## Description\n\n` +
        `${await this.renderBBCode(classInfo.description) ?? "No description provided"}\n`)

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
          if (member.isPrivate && !this.renderPrivateMembers)
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
          if (method.isPrivate && !this.renderPrivateMembers)
            continue

          const link = `#${this.slug(method.name)}`

          const type = await this.renderType(method.returnType)
          const name = method.name
          const params = await this.renderParams(method.params)
          const qualifiers = method.qualifiers ?? ""

          sink.write(`| ${type} | [${name}](${link})(${params}) ${qualifiers} |\n`)
        }
      }

      if (classInfo.signals.length) {
        sink.write(`\n## Signals\n\n`)

        for (const signal of classInfo.signals) {
          const name = signal.name
          const params = await this.renderParams(signal.params)
          const slug = this.slug(name)

          sink.write(
            `#### <span id="${slug}">${name} ( ${params} )</span>\n\n` +
            `${await this.renderBBCode(signal.description) ?? "No description provided"}\n\n` + 
            `---\n\n`
          )
        }
      }

      if (classInfo.constants.length) {
        sink.write(`\n## Constants\n`)

        for (const constant of classInfo.constants) {
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
          if (member.isPrivate && !this.renderPrivateMembers)
            continue

          const name = member.name
          const type = await this.renderType(member.type)
          const defaultSuffix = member.default ? `= \`${member.default}\`` : ""
          const description = await this.renderBBCode(member.description)
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
          if (method.isPrivate && !this.renderPrivateMethods)
            continue

          const type = await this.renderType(method.returnType)
          const name = method.name
          const params = await this.renderParams(method.params)
          const qualifiers = method.qualifiers ?? ""
          const description = method.description
          const slug = this.slug(name)

          sink.write(
            `#### <span id="${slug}">${type} ${name} ( ${params} ) ${qualifiers}</span>\n\n` + 
            `${await this.renderBBCode(description)}\n\n` +
            `---\n\n`
          )
        }
      }

      sink.end()
      console.log(`Rendered ${file.name}`)
    }
  }

  private async renderBBCode(tokens: BBCode | undefined): Promise<string> {
    if (tokens === undefined) return ""

    const result = []
    for (const token of tokens) {
      if (token.type === "string")
        result.push(token.text)
      else if(token.type === "br")
        result.push("\n")
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
        result.push("\n\n```gd\n" + token.code + "```\n\n")
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
          console.error("Failed to lookup class:", token.tag.tag)
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
    console.error("Encountered unknown token", token)
  }

  private slug(text: string): string {
    return text.replace(/[^\d\w]/g, "-").toLowerCase()
  }

  private hasMembers(classInfo: Class): boolean {
    if (!this.renderPrivateMembers)
      return classInfo.members.some(m => !m.isPrivate)
    else
      return classInfo.members.length > 0
  }

  private hasMethods(classInfo: Class): boolean {
    if (!this.renderPrivateMethods)
      return classInfo.methods.some(m => !m.isPrivate)
    else
      return classInfo.methods.length > 0
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
    const typeLink = await this.getTypeLink(type)
    return typeLink
      ? `[${type}](${typeLink})`
      : type
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

    return `*${type}.${displayName}*`
  }
}
