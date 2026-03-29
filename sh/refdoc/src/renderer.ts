import type { ClassDB } from "./classdb";
import type { Class } from "./class.types";
import type { BBCode, BBCodeToken } from "./bb.parser";

export interface Renderer {
  render(classDB: ClassDB, targetDirectory: string): Promise<void>;
}

export class MarkdownRenderer implements Renderer {
  private renderPrivate = false;

  async render(classDB: ClassDB, targetDirectory: string): Promise<void> {
    for (const classInfo of classDB.classes) {
      const file = Bun.file(targetDirectory + "/" + classInfo.name + ".md")

      // Clear file before writing
      if (await file.exists()) 
        await file.write("")
      const sink = file.writer();

      // Overview
      sink.write(
        `# ${classInfo.name}\n\n` +
        `**Inherits:** ${classInfo.inherits}\n\n` +
        `${this.renderBBCode(classInfo.briefDescription)}\n\n` + 
        `## Description\n\n` +
        `${this.renderBBCode(classInfo.description) ?? "No description provided"}\n`)

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
          if (!member.isPrivate)
            if (member.default)
              sink.write(`| ${member.type} | ${member.name} | \`${member.default}\` |\n`)
            else
              sink.write(`| ${member.type} | ${member.name} |  |\n`)
      }

      if (classInfo.methods.length) {
        sink.write(
          `\n## Methods\n\n` +
          `| Return Type | Name |\n` +
          `| -- | -- |\n`
        )

        for (const method of classInfo.methods) {
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
            `${this.renderBBCode(signal.description) ?? "No description provided"}\n\n` + 
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
            `${this.renderBBCode(constant.description)}\n\n`
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
              `${this.renderBBCode(member.description)}\n\n`
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
            `${this.renderBBCode(description)}\n\n`)
        }
      }

      sink.end()
      console.log(`Rendered ${file.name}`)
    }
  }

  private renderBBCode(tokens: BBCode | undefined): string {
    if (tokens === undefined) return ""

    const result = []
    for (const token of tokens) {
      if (token.type === "string")
        result.push(token.text)
      else if(token.type === "br")
        result.push("\n")
      else if(token.type === "i")
        result.push(`_${this.renderBBCode(token.content)}_`)
      else if(token.type === "b")
        result.push(`**${this.renderBBCode(token.content)}**`)
      else if(token.type === "u")
        result.push(`_${this.renderBBCode(token.content)}_`)
      else if(token.type === "s")
        result.push(`~~${this.renderBBCode(token.content)}~~`)
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
      else {
        result.push(
          "\n\n```\n" +
          JSON.stringify(token, undefined, 2) +
          "\n```\n\n"
        )
      }
    }

    return result.join("")
  }

  private hasMembers(classInfo: Class): boolean {
    if (!this.renderPrivate)
      return classInfo.members.some(m => !m.isPrivate)
    else
      return classInfo.members.length > 0
  }
}
