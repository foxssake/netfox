import { $ } from "bun";

interface Semver {
  major: number;
  minor: number;
  patch: number;
  suffix: string | undefined;
}

function parseSemver(version: string): Semver | undefined {
  const pattern = /v?(\d+)\.(\d+)\.(\d+)([\.-].*)?/;
  const matches = pattern.exec(version);
  if (matches === null) return undefined;

  const result = {
    major: parseInt(matches[1]),
    minor: parseInt(matches[2]),
    patch: parseInt(matches[3]),
    suffix: matches[4],
  } as Semver;

  if (result.suffix === "") result.suffix = undefined;

  return result;
}

function compareSemver(a: Semver, b: Semver): number {
  if (a.major != b.major) return a.major - b.major;
  if (a.minor != b.minor) return a.minor - b.minor;
  if (a.patch != b.patch) return a.patch - b.patch;
  if (a.suffix != b.suffix) {
    if (a.suffix === undefined) return 1; // a has no suffix, therefore it's more mature
    if (b.suffix === undefined) return -1; // b has no suffix, therefore it's more mature
    if (a.suffix !== undefined && b.suffix !== undefined)
      return a.suffix.localeCompare(b.suffix);
  }
  return 0;
}

function stringifySemver(version: Semver): string {
  return `${version.major}.${version.minor}.${version.patch}${version.suffix ?? ""}`;
}

async function main(): Promise<number> {
  const versions = (await Array.fromAsync($`git tag`.quiet().lines()))
    .filter((it) => it.startsWith("v"))
    .map((it) => parseSemver(it))
    .filter((it) => it !== undefined)
    .sort(compareSemver)
    .reverse()
    .map(stringifySemver);

  console.log("Found versions", versions);
  return 0;
}

process.exit(await main());
