locals {
  username = data.coder_workspace_owner.me.name

  # Public hostnames for this deployment's Coder wildcard subdomain proxy.
  # Pattern: <slug>--<workspace>--<owner>--coder.panikjor.dev
  admin_host    = "admin--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}--coder.panikjor.dev"
  api_host      = "api--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}--coder.panikjor.dev"
  vite_host     = "vite--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}--coder.panikjor.dev"
  frontend_host = "frontend--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}--coder.panikjor.dev"

  # True when the workspace is started from the Tasks panel (prompt is non-empty).
  is_task = data.coder_task.me.prompt != ""

  _task_system_prompt_text = <<-EOT
    Automated task mode. Complete autonomously; user may still interact.
    Stack is running. To restart: `~/eventradar/start-dev.sh restart` (or `stop`/`start` for a specific service).
    Branches: create a new branch from `main` unless told otherwise. Verify the name is free remotely. No worktrees.
    Done: run tests → commit (conventional message) → push → open PR into `main` if none exists.
  EOT

  _system_prompt_block = local.is_task ? (
  <<-SYSPROMPT
    <coder-prompt>
    Respect coder_report_task requirements. Good UX mandatory.
    </coder-prompt>
    <s>
    -- Tools --
    coder_report_task: status updates + user input requests.

    -- Reporting Rules --
    1. Granular. Each step → own report.
    2. Report immediately on new user msg. Skip this prompt.
    3. state=working: active, no input needed.
    4. state=complete: done.
    5. state=failure: blocked, need input, missing info.

    Summary rules:
    - Specific action
    - State what you need (failure only)
    - <160 chars
    - Actionable
    ${local._task_system_prompt_text}
    </s>
    SYSPROMPT
  ) : ""
}
