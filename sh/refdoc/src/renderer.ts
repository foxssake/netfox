import type { ClassDB } from "./classdb";
import type { Class } from "./types";

export interface Renderer {
  render(classDB: ClassDB, targetDirectory: string): Promise<void>;
}

export class MarkdownRenderer implements Renderer {
  private renderPrivate = false;

  async render(classDB: ClassDB, targetDirectory: string): Promise<void> {
    for (const classInfo of classDB.classes) {
      const file = Bun.file(targetDirectory + "/" + classInfo.name + ".md")
      const sink = file.writer();

      // Overview
      sink.write(
        `# ${classInfo.name}\n\n` +
        `**Inherits:** ${classInfo.inherits}\n\n` +
        `${classInfo.briefDescription}\n\n` + 
        `## Description\n\n` +
        `${classInfo.description ?? "No description provided"}\n`)

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
            `${signal.description ?? "No description provided"}\n\n` + 
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
            `${constant.description}\n\n`
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
              `${member.description}\n\n`
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
            `${description}\n\n`)
        }
      }

      sink.end()
      console.log(`Rendered ${file.name}`)
    }
  }

  private hasMembers(classInfo: Class): boolean {
    if (!this.renderPrivate)
      return classInfo.members.some(m => !m.isPrivate)
    else
      return classInfo.members.length > 0
  }
}
