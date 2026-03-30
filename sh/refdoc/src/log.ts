export interface Log {
  print(...args: any): void;
  error(...args: any): void;
  errorInFile(file: string, ...args: any): void;

  group(name: String): void;
  endgroup(): void;
}

export class ConsoleLog implements Log {
  print(...args: any): void {
    console.log(...args)
  }

  error(...args: any): void {
    console.error(...args)
  }

  errorInFile(file: string, ...args: any): void {
    console.error(`(${file})`, ...args)
  }

  group(name: String): void {
    console.group(name)
  }

  endgroup(): void {
      console.groupEnd()
  }
}

export class GithubLog implements Log {
  print(...args: any): void {
    console.log(...args)
  }

  error(...args: any): void {
    console.log("::error::", ...args)
  }

  errorInFile(file: string, ...args: any): void {
    console.log(`::error file=${file}::`, ...args)
  }

  group(name: String): void {
    console.log(`::group::${name}`)
  }

  endgroup(): void {
    console.log("::endgroup::")
  }
}

export const log = process.env.GITHUB_ACTIONS !== undefined
  ? new GithubLog()
  : new ConsoleLog();
