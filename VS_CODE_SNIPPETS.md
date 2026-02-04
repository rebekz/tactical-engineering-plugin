# VS Code Snippets for Claude Code

Based on IndyDevDan's VS Code snippets, this file contains useful snippets for working with Claude Code.

## Installation

1. Open VS Code
2. Go to Settings > User Snippets
3. Select the language (e.g., "Markdown")
4. Paste the snippets below

## Agent Skill Template

```json
"Agent Skill Template": {
  "prefix": "agsk",
  "body": [
    "---",
    "name: ${1:skill-name}",
    "description: ${2:What this skill does. Use when ${3:trigger conditions}.}",
    "allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, TodoWrite, WebSearch, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode",
    "model: opus",
    "context: fork",
    "agent: general-purpose",
    "user-invocable: true",
    "---",
    "",
    "# ${4:Skill Title}",
    "",
    "## Purpose",
    "",
    "${5}",
    "",
    "## Instructions",
    "",
    "${6}",
    "",
    "## Workflow",
    "",
    "1. ${7}",
    "2. ${8}",
    "3. ${9}",
    "",
    "## Report",
    "",
    "${10}"
  ],
  "description": "Agent Skill template with all frontmatter options"
}
```

## Agent Subagent Template

```json
"Agent Subagent Template": {
  "prefix": "agag",
  "body": [
    "---",
    "name: ${1:agent-name}",
    "description: ${2:What this agent does. Use proactively when ${3:trigger conditions}.}",
    "tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill",
    "model: opus",
    "permissionMode: default",
    "skills:",
    " - ${4:skill-name-1}",
    " - ${5:skill-name-2}",
    "color: ${6:cyan}",
    "---",
    "",
    "# ${7:Agent Title}",
    "",
    "## Purpose",
    "",
    "You are ${8:purpose definition}.",
    "",
    "## Instructions",
    "",
    "${9}",
    "",
    "## Workflow",
    "",
    "When invoked, follow these steps:",
    "",
    "1. ${10}",
    "2. ${11}",
    "3. ${12}",
    "",
    "## Report",
    "",
    "${13}"
  ],
  "description": "Agent Subagent template with all frontmatter options"
}
```

## Agentic Prompt Engineering

```json
"Agentic Prompt Engineering": {
  "prefix": "agp",
  "body": [
    "---",
    "model: opus",
    "description: ${1:description}",
    "argument-hint: [${2:arg1}] [${3:arg2}]",
    "allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, EnterPlanMode, ExitPlanMode",
    "context: fork",
    "agent: general-purpose",
    "---",
    "",
    "# Purpose",
    "",
    "${4}",
    "",
    "## Variables",
    "",
    "${5}",
    "",
    "## Codebase Structure",
    "",
    "${6}",
    "",
    "## Instructions",
    "",
    "${7}",
    "",
    "## Workflow",
    "",
    "${8}",
    "",
    "## Report",
    "",
    "${9}"
  ],
  "description": "Agentic prompt with frontmatter"
}
```

## Command Template

```json
"Command Template": {
  "prefix": "agcmd",
  "body": [
    "---",
    "name: ${1:command-name}",
    "description: ${2:What this command does.}",
    "argument-hint: [${3:arg1}] [${4:arg2}]",
    "allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill",
    "model: opus",
    "context: fork",
    "agent: general-purpose",
    "user-invocable: true",
    "---",
    "",
    "# ${5:Command Title}",
    "",
    "## Purpose",
    "",
    "${6}",
    "",
    "## Usage",
    "",
    "```bash",
    "/${1} ${7:args}",
    "```",
    "",
    "## Instructions",
    "",
    "${8}",
    "",
    "## Example",
    "",
    "```bash",
    "/${1} \"${9:example}\"",
    "```"
  ],
  "description": "Command template with frontmatter"
}
```

## Learnings Document

```json
"Learnings Document": {
  "prefix": "aglearn",
  "body": [
    "---",
    "title: Learnings from ${1:topic}",
    "date: ${2:${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DATE}}",
    "tags: [${3:tags}]",
    "category: ${4:category}",
    "module: ${5:module}",
    "symptoms: [${6:symptoms}]",
    "---",
    "",
    "## What Worked",
    "",
    "${7}",
    "",
    "## What Didn't Work",
    "",
    "${8}",
    "",
    "## Lessons Learned",
    "",
    "${9}",
    "",
    "## Recommendations for Future",
    "",
    "${10}"
  ],
  "description": "Learnings document template"
}
```

## Usage

1. Type the prefix (e.g., `agsk`) in your editor
2. Press Tab to expand
3. Fill in the placeholders using Tab to navigate

## Original Source

Based on [IndyDevDan's Skill, Subagent, and Slash Command VSCode Snippets](https://gist.github.com/disler/d9f1285892b9faf573a0699aad70658f)
