# swift-brief-kit

What a codebase is — language, how to build it, what is in it, what is moving — read from
the filesystem and git.

```swift
import BriefKit

let brief = try Briefer.brief(path: "~/Developer/thing")

brief.primary?.ecosystem        // .rust
brief.primary?.isWorkspace      // true
brief.commands                  // build / test / run, from the manifest
brief.git?.churn                // the files changed most lately
brief.tests.fileCount           // where the tests are and how many
```

## What it detects

Swift, JavaScript/TypeScript, Python, Rust, PHP, Go and Ruby — **from the manifest where
there is one, and from the source files where there is not.**

That fallback is not decoration. Probing this machine before building found two directories
of Python living as loose `.py` scripts with no `pyproject.toml`, `setup.py` or
`requirements.txt` anywhere. A manifest-only detector reports those as "nothing here".

## Workspaces are the normal case

The same probe found one project with **104 `Cargo.toml`** files and another with **19
`package.json`**. Reporting the root manifest as the whole project would describe one crate
of a hundred and four, so a workspace is detected as one and its members counted.

It also means a workspace root's dependency list is *empty on purpose*: a root declares
members, not dependencies, and reporting the stray entries it happens to carry would claim
"1 dependency" of a project with a hundred crates.

## One pass

Every question — languages, size, tests, manifests, layout — comes from a single walk. A tool
whose promise is "faster than the twenty commands you'd otherwise run" cannot walk the tree
twenty times to deliver it.

Build output and dependency directories are skipped by a fixed list rather than a `.gitignore`
parser: the directories that make a walk slow are the same everywhere, and gitignore pattern
semantics are a project of their own. **21,554 files across 4.1 GB survey in 0.9 seconds.**

## Manifest reading is deliberately shallow

`Package.swift` is a Swift *program* — reading it properly means compiling and running it.
`Cargo.toml` is TOML, which is a real grammar. What is implemented is pattern matching over
the shapes these files actually take, so every reader returns what it is confident about and
omits the rest: **a missing dependency is a smaller lie than an invented one.**

## Git

Branch, tag, uncommitted count, recent commits and churn, by shelling out to `git` — four
processes, against a library's worth of work to parse packfiles and ref formats correctly.
Churn is bounded to the last 200 commits, because it means "where the work is now" and
averaging it over years answers a different question.

Commit fields are separated by a unit separator, not a comma or a pipe: a commit subject can
contain anything a person can type, including whatever delimiter looked safe.

## Requirements

macOS 14+ / iOS 17+, Swift 6.2. Foundation only.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-brief-kit.git", from: "0.1.0")
```

## The CLI

[`brief`](https://github.com/arraypress/swift-brief-cli) is this library as a command-line tool.

## License

MIT
