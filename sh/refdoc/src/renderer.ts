import type { ClassDB } from "./classdb";
import type { Class } from "./class.types";
import type { BBCode, BBCodeToken } from "./bb.parser";

export interface Renderer {
  render(targetDirectory: string): Promise<void>;
}

export class MarkdownRenderer implements Renderer {
  constructor(
    private classDB: ClassDB,
    private renderPrivateMembers: boolean = false,
    private renderPrivateMethods: boolean = false
  ) {}

  async render(targetDirectory: string): Promise<void> {
    for (const classInfo of this.classDB.classes) {
      const file = Bun.file(targetDirectory + "/" + classInfo.name + ".md")

      // Clear file before writing
      if (await file.exists()) 
        await file.write("")
      const sink = file.writer();

      // Overview
      sink.write(
        `# ${classInfo.name}\n\n` +
        `**Inherits:** ${classInfo.inherits}\n\n` +
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

        for (const member of classInfo.members)
          if (!member.isPrivate || this.renderPrivateMembers)
            if (member.default)
              sink.write(`| ${member.type} | ${member.name} | \`${member.default}\` |\n`)
            else
              sink.write(`| ${member.type} | ${member.name} |  |\n`)
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

          const type = method.returnType
          const name = method.name
          const params = method.params.map(p => `${p.type} ${p.name}`).join(", ")
          const qualifiers = method.qualifiers ?? ""

          sink.write(`| ${type} | ${name}(${params}) ${qualifiers} |\n`)
        }
      }

      if (classInfo.signals.length) {
        sink.write(`\n## Signals\n\n`)

        for (const signal of classInfo.signals) {
          const name = signal.name
          const params = signal.params.map(p => `${p.type} ${p.name}`).join(", ")

          sink.write(
            `### ${name} ( ${params} )\n\n` +
            `${await this.renderBBCode(signal.description) ?? "No description provided"}\n\n` + 
            `---\n\n`
          )
        }
      }

      if (classInfo.constants.length) {
        sink.write(`\n## Constants\n`)

        for (const constant of classInfo.constants)
          sink.write(
            `### ${constant.name}\n\n` + 
            `= \`${constant.value}\`\n\n` +
            `${await this.renderBBCode(constant.description)}\n\n`
          )
      }

      // Descriptions
      if (this.hasMembers(classInfo)) {
        sink.write(`\n## Property Descriptions\n\n`)

        for (const member of classInfo.members)
          if (!member.isPrivate)
            sink.write(
              `### ${member.type} ${member.name}\n` + 
              (member.default ? `= \`${member.default}\`\n` : "") +
              `${await this.renderBBCode(member.description)}\n\n`
            )
      }

      if (classInfo.methods.length) {
        sink.write(`\n## Method Descriptions\n\n`)

        for (const method of classInfo.methods) {
          const type = method.returnType
          const name = method.name
          const params = method.params.map(p => `${p.type} ${p.name}`).join(", ")
          const qualifiers = method.qualifiers ?? ""
          const description = method.description

          sink.write(
            `### ${type} ${name} ( ${params} ) ${qualifiers}\n\n` + 
            `${await this.renderBBCode(description)}\n\n`)
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
        result.push("\n\n```" + token.code + "```\n\n")
      else if(token.type === "method")
        result.push(`[${token.class ? token.class + "." : ""}${token.name}()](#)`) // TODO: Link
      else if (token.type === "param")
        result.push(`\`${token.name}\``)
      else if(token.type === "member")
        result.push(`[${token.class ? token.class + "." : ""}${token.name}](#)`) // TODO: Link
      else if(token.type === "constant")
        result.push(`[${token.class ? token.class + "." : ""}${token.name}](#)`) // TODO: Link
      else if(token.type === "signal")
        result.push(`[${token.class ? token.class + "." : ""}${token.name}()](#)`) // TODO: Link
      else if(token.type === "?") {
        const className = token.tag.tag
        const localClass = this.classDB.findByName(className)
        const externalLink = localClass ? undefined : await this.classDB.lookupExternal(className)
        if (localClass) {
          // It's a link to a local class
          result.push(`[${localClass?.name}](#)`) // TODO: Link
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
}
