# Graph Report - dotfiles  (2026-08-22)

## Corpus Check
- 80 files · ~25,978 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 245 nodes · 300 edges · 49 communities (42 shown, 7 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4456f719`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Graphify Skill Internals
- CLI Cheatsheets & Shell Aliases
- Claude Agent Workflow Skills
- WezTerm Appearance & Session UI
- WezTerm Worktree Workspaces
- Dotfiles Repo Overview & Tooling
- WezTerm Tab Title/Coloring
- Git-Push Safety Hooks
- Graphify Incremental Update Engine
- WezTerm Worktree CLI Script
- Lazygit AI Commit Message
- Claude Push Control Toggle
- Lazygit AI Squash Commit
- Nvim Light/Dark Colorscheme Toggle
- Git Branch-Checkout Safety Hook
- WezTerm Statusline Script
- Tab Navigation Keybind Parity
- Dotfiles Setup Script
- Close Pane/Tab Keybind Parity
- Scroll Keybind Parity
- Vimium Config
- Browser History Keybind Parity

## God Nodes (most connected - your core abstractions)
1. `graphify Skill` - 16 edges
2. `Daily Task Planning Skill` - 9 edges
3. `M.setup()` - 8 edges
4. `Write-Approval Gate Rule` - 8 edges
5. `dotfiles Repository` - 8 edges
6. `graphify Extraction Subagent Prompt Spec` - 7 edges
7. `Global CLAUDE.md Instructions` - 7 edges
8. `Bug Investigation Workflow Skill` - 7 edges
9. `Dev Workflow Shared Skill` - 7 edges
10. `Notion Task Workflow Skill` - 7 edges

## Surprising Connections (you probably didn't know these)
- `gh pr view --web (for image/video attachments)` --semantically_similar_to--> `PR Workflow Skill`  [INFERRED] [semantically similar]
  docs/git-cheatsheet.md → claude/rules/skill-authoring.md
- `dotfiles Repository` --references--> `Global CLAUDE.md Instructions`  [EXTRACTED]
  README.md → claude/CLAUDE.md
- `rules/ Not Auto-Loaded — Execution Must Live in Skill` --semantically_similar_to--> `Conditional references/*.md Loading Pattern`  [INFERRED] [semantically similar]
  claude/rules/skill-authoring.md → claude/skills/graphify/SKILL.md
- `lazygit Ctrl+g: AI commit type/subject via git-cz` --references--> `lazygit customCommand <c-g>`  [EXTRACTED]
  docs/git-cheatsheet.md → lazygit/config.yml
- `lazygit Ctrl+x: AI squash + message generation` --references--> `lazygit customCommand <c-x>`  [EXTRACTED]
  docs/git-cheatsheet.md → lazygit/config.yml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **daily-task-planning sub-steps: notion-task-planning + pr-task-planning** — claude_skills_daily_task_planning_skill, claude_skills_notion_task_planning_skill, claude_skills_pr_task_planning_skill [EXTRACTED 1.00]
- **daily-task-logs notebook mediates notion-task-workflow write / notion-task-planning read, orchestrated by daily-task-planning** — claude_skills_notion_task_workflow_skill, claude_skills_notion_task_planning_skill, claude_skills_daily_task_planning_skill [EXTRACTED 1.00]
- **Daily Task Planning: Budget to Candidates to Herdr Delegation** — claude_skills_daily_task_planning_skill, claude_skills_pr_task_planning_skill, claude_skills_notion_task_planning_skill, claude_skills_bug_investigation_workflow_skill, claude_skills_implementation_workflow_skill [INFERRED 0.85]
- **Genre Skills delegate pre-check/test/handoff/PR-draft to dev-workflow-shared** — claude_skills_implementation_workflow_skill, claude_skills_testing_workflow_skill, claude_skills_dev_workflow_shared_skill, claude_skills_bug_investigation_workflow_skill [INFERRED 0.85]
- **Development Workflow: Investigation to Shared Steps to Approval Gate** — claude_skills_bug_investigation_workflow_skill, claude_skills_dev_workflow_shared_skill, claude_rules_write_approval, claude_skills_notion_task_workflow_skill [INFERRED 0.85]
- **graphify's Conditional Reference-Loading Pattern** — claude_skills_graphify_skill, claude_skills_graphify_references_add_watch, claude_skills_graphify_references_exports, claude_skills_graphify_references_extraction_spec, claude_skills_graphify_references_github_and_merge, claude_skills_graphify_references_hooks, claude_skills_graphify_references_query, claude_skills_graphify_references_transcribe [INFERRED 0.85]

## Communities (49 total, 7 thin omitted)

### Community 0 - "Graphify Skill Internals"
Cohesion: 0.07
Nodes (35): graphify Skill Trigger Note, rules/ Not Auto-Loaded — Execution Must Live in Skill, graphify add & --watch Reference, URL Ingestion (graphify.ingest), Folder Watch Mode (graphify.watch), graphify Extra Exports & Benchmark Reference, FalkorDB Cypher Export, graphify MCP Stdio Server (+27 more)

### Community 1 - "CLI Cheatsheets & Shell Aliases"
Cohesion: 0.07
Nodes (13): lazygit config.yml, tab-check.sh script, EDITOR, _herdr_report_id(), hwsnew(), hwtnew(), _nb_is_pdf_url(), nba() (+5 more)

### Community 2 - "Claude Agent Workflow Skills"
Cohesion: 0.18
Nodes (20): Global CLAUDE.md Instructions, find_pr_write_action(), main(), Skill Authoring Convention, Write-Approval Gate Rule, Bug Investigation Workflow Skill, Herdr Parallel Agent Tool, Daily Task Planning Skill (+12 more)

### Community 3 - "WezTerm Appearance & Session UI"
Cohesion: 0.14
Nodes (9): hex_to_rgba(), M.setup(), register_transparent_tab_bar(), has_saved_state(), M.escape_file_name(), on_gui_ready(), is_vim(), M.setup() (+1 more)

### Community 4 - "WezTerm Worktree Workspaces"
Cohesion: 0.28
Nodes (14): basename(), close_workspace_panes(), confirm(), do_create(), list_workspaces(), M.create_workspace(), M.delete_workspace(), M.setup() (+6 more)

### Community 5 - "Dotfiles Repo Overview & Tooling"
Cohesion: 0.18
Nodes (11): dotfiles Repository, generate_pyright_paths.py Script, Git Cheatsheet, lazy.nvim Plugin Manager, mason.nvim LSP/DAP Installer, Neovim, Neovim Cheatsheet, ROS 2 Workspace Build Notes (+3 more)

### Community 6 - "WezTerm Tab Title/Coloring"
Cohesion: 0.38
Nodes (10): basename(), extract_project_name(), get_tab_colors(), has_zoomed_pane(), is_claude_process(), is_ssh_process(), M.current_tab_colors(), M.setup() (+2 more)

### Community 7 - "Git-Push Safety Hooks"
Cohesion: 0.31
Nodes (8): find_git_push(), is_git_push(), main(), split_segments(), Hook vs Skill Enforcement Split, graphify Hooks & CLAUDE.md Integration Reference, graphify Native CLAUDE.md Integration, graphify Post-Commit Auto-Rebuild Hook

### Community 8 - "Graphify Incremental Update Engine"
Cohesion: 0.25
Nodes (5): graphify --update / --cluster-only reference, unstamped-on-failure manifest re-queue design, replace-on-re-extract merge design, build_merge(), save_manifest()

### Community 9 - "WezTerm Worktree CLI Script"
Cohesion: 0.50
Nodes (8): cmd_check_dirty(), cmd_create(), cmd_list(), cmd_remove(), ensure_registry(), has_uncommitted_changes(), wezterm-worktree.sh script, usage()

### Community 10 - "Lazygit AI Commit Message"
Cohesion: 0.40
Nodes (4): lazygit Ctrl+g: AI commit type/subject via git-cz, lazygit customCommand <c-g>, NVM_DIR, ai-commit-msg.sh script

### Community 11 - "Claude Push Control Toggle"
Cohesion: 0.70
Nodes (4): cmd_off(), cmd_on(), claude-git-push-ctl.sh script, usage()

### Community 12 - "Lazygit AI Squash Commit"
Cohesion: 0.50
Nodes (3): lazygit Ctrl+x: AI squash + message generation, lazygit customCommand <c-x>, ai-squash-commit.sh script

### Community 13 - "Nvim Light/Dark Colorscheme Toggle"
Cohesion: 0.83
Nodes (3): apply_dark(), apply_light(), M.toggle()

### Community 16 - "Tab Navigation Keybind Parity"
Cohesion: 0.67
Nodes (3): WezTerm Shift+H/Shift+L = prev/next tab, Vimium H/L = prev/next tab, map H previousTab / map L nextTab

## Knowledge Gaps
- **43 isolated node(s):** `tab-check.sh script`, `EDITOR`, `aliases.sh script`, `NVM_DIR`, `ai-commit-msg.sh script` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `graphify Skill` connect `Graphify Skill Internals` to `Git-Push Safety Hooks`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `PR Workflow Skill` connect `Claude Agent Workflow Skills` to `CLI Cheatsheets & Shell Aliases`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `Skill Authoring Convention` connect `Claude Agent Workflow Skills` to `Graphify Skill Internals`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **What connects `tab-check.sh script`, `EDITOR`, `aliases.sh script` to the rest of the system?**
  _43 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Graphify Skill Internals` be split into smaller, more focused modules?**
  _Cohesion score 0.06722689075630252 - nodes in this community are weakly interconnected._
- **Should `CLI Cheatsheets & Shell Aliases` be split into smaller, more focused modules?**
  _Cohesion score 0.07386363636363637 - nodes in this community are weakly interconnected._
- **Should `WezTerm Appearance & Session UI` be split into smaller, more focused modules?**
  _Cohesion score 0.14210526315789473 - nodes in this community are weakly interconnected._