#!/usr/bin/env bun

import { $ } from "bun";

const ERR_NO_TAGS = 1;

const REPO_LINK = "https://github.com/foxssake/netfox";

interface Semver {
  prefix: string | undefined;
  major: number;
  minor: number;
  patch: number;
  suffix: string | undefined;
}

interface Commit {
  hash: string;
  description: string;
}

function parseSemver(version: string): Semver | undefined {
  const pattern = /(v?)(\d+)\.(\d+)\.(\d+)([\.-].*)?/;
  const matches = pattern.exec(version);
  if (matches === null) return undefined;

  const result = {
    prefix: matches[1],
    major: parseInt(matches[2]),
    minor: parseInt(matches[3]),
    patch: parseInt(matches[4]),
    suffix: matches[5],
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
  return `${version.prefix ?? ""}${version.major}.${version.minor}.${version.patch}${version.suffix ?? ""}`;
}

function parseOnelineCommit(line: string): Commit | undefined {
  const pattern = /([\w\d]+) (.+)/;
  const matches = pattern.exec(line);
  if (matches === null) return undefined;

  return {
    hash: matches[1],
    description: matches[2],
  };
}

function renderCommitDescription(description: string): string {
  const pattern = /(.*)\(#([\d]+)\)$/;
  const matches = pattern.exec(description);
  if (matches === null) return description;

  const body = matches[1];
  const pullId = matches[2];
  const link = `${REPO_LINK}/pull/${pullId}`;
  return `${body}([#${pullId}](${link}))`;
}

function renderCommit(commit: Commit): string {
  const link = `${REPO_LINK}/commit/${commit.hash}`;
  const body = renderCommitDescription(commit.description);
  return `${body} [🔗](${link})`;
}

function renderRelease(tag: string, commits: Commit[]): string {
  const title = tag === "main" ? "Latest" : tag;
  const body = commits.map((it) => "* " + renderCommit(it)).join("\n");
  return `## ${title}\n${body}`;
}

async function main(): Promise<number> {
  const versions = (await Array.fromAsync($`git tag`.quiet().lines()))
    .filter((it) => it.startsWith("v"))
    .map((it) => parseSemver(it))
    .filter((it) => it !== undefined)
    .sort(compareSemver)
    .reverse()
    .map(stringifySemver);

  if (versions.length == 0) {
    console.error("No version tags found!");
    return ERR_NO_TAGS;
  }

  versions.unshift("main");

  const logIntervals = versions.map((it, idx) => [
    it,
    versions.at(idx + 1) ?? "",
  ]);

  const logs = await Promise.all(
    logIntervals
      .map(([from, to]) =>
        to !== ""
          ? $`git log --format=oneline ${to}..${from}`.quiet().lines()
          : $`git log --format=oneline ${from}`.quiet().lines(),
      )
      .map((it) => Array.fromAsync(it))
      .map((it) =>
        it.then((lines) =>
          lines
            .map(parseOnelineCommit)
            .filter((commit) => commit !== undefined),
        ),
      ),
  );

  const releaseNotes = versions.map((version, idx) => [
    version,
    logs.at(idx) ?? [],
  ]) as [string, Commit[]][];

  console.log("# Changelog\n");
  console.log(
    releaseNotes
      .map(([version, commits]) => renderRelease(version, commits))
      .join("\n\n"),
  );

  return 0;
}

process.exit(await main());
