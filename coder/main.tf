terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.4.1"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_task" "me" {}

# Require GitHub authentication for Git operations in the workspace.
# The id must match CODER_EXTERNAL_AUTH_0_ID on your Coder server.
data "coder_external_auth" "github" {
  id = "primary-github"
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -euo pipefail

    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Pre-accept the Claude Code bypass-permissions trust dialog.
    mkdir -p ~/.claude
    echo '{"skipDangerousModePermissionPrompt": true}' > ~/.claude/settings.json

    # Run setup on first start only: clone repos, install deps.
    if [ ! -f ~/.setup_done ]; then
      echo "Running first-start setup..."

      git config --global pull.rebase false

      git clone https://github.com/IlliaVeremiev/eventradar ~/eventradar
      git clone https://github.com/IlliaVeremiev/eventradar-api ~/eventradar/api
      git clone https://github.com/IlliaVeremiev/eventradar-ui ~/eventradar/frontend

      cd ~/eventradar/api
      composer install
      npm install
      cp .env.coder .env
      php artisan key:generate
      php artisan jwt:secret --force

      # Wait for Docker daemon (DinD may still be starting on first boot).
      until docker info > /dev/null 2>&1; do sleep 3; done
      docker compose up -d --quiet-pull

      ~/eventradar/coder/scripts/wait-for-mysql.sh

      php artisan migrate
      php artisan db:seed AdminUserSeeder

      cd ~/eventradar/frontend
      npm install

      touch ~/.setup_done
      echo "First-start setup complete."
    fi

    # Start dev servers via tmux manager on every start.
    ~/eventradar/start-dev.sh start
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"

    # Consumed by Laravel's vite.config.js so the Vite plugin writes the correct
    # https://<subdomain> URLs into public/hot instead of localhost addresses.
    VITE_DEV_SERVER_VITE_HOST  = local.vite_host
    VITE_DEV_SERVER_ADMIN_HOST = local.admin_host

    # Consumed by eventradar-ui to locate backend services inside the Coder proxy.
    VITE_CODER_API_URL      = "https://${local.api_host}"
    VITE_CODER_ADMIN_URL    = "https://${local.admin_host}"
    VITE_CODER_FRONTEND_URL = "https://${local.frontend_host}"

    CODER_AGENT_URL                 = var.coder_agent_url
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = 1
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

module "code-server" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/code-server/coder"
  version = "~> 1.0"

  agent_id = coder_agent.main.id
  order    = 1
}

module "jetbrains" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/jetbrains/coder"
  version    = "~> 1.1"
  agent_id   = coder_agent.main.id
  agent_name = "main"
  folder     = "/home/coder"
  tooltip    = "You need to [install JetBrains Toolbox](https://coder.com/docs/user-guides/workspace-access/jetbrains/toolbox) to use this app."
}

module "claude-code" {
  source   = "registry.coder.com/coder/claude-code/coder"
  version  = "4.9.2"
  agent_id = coder_agent.main.id
  workdir  = "/home/coder/eventradar"

  claude_code_oauth_token = var.anthropic_oauth_token
  report_tasks            = true

  ai_prompt = data.coder_task.me.prompt

  post_install_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    CLAUDE_MD="$HOME/.claude/CLAUDE.md"
    mkdir -p "$(dirname "$CLAUDE_MD")"
    cat > "$CLAUDE_MD" << 'CLAUDE_EOF'
${local._system_prompt_block}
CLAUDE_EOF
    echo "post_install_script: wrote $CLAUDE_MD"
  EOT

  order = 2
}

resource "coder_ai_task" "claude_code" {
  count  = data.coder_workspace.me.start_count
  app_id = module.claude-code.task_app_id
}

resource "docker_network" "private_network" {
  name = "coder-${data.coder_workspace.me.id}"
}

resource "docker_volume" "docker_volume" {
  name = "coder-${data.coder_workspace.me.id}-docker"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    build_args = {
      USER = local.username
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "dind" {
  image      = "docker:dind"
  privileged = true
  name       = "dind-${data.coder_workspace.me.id}"
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]
  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["docker"]
  }
  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.docker_volume.name
    read_only      = false
  }
}

resource "coder_script" "docker_ready" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  display_name = "Wait for Docker"
  icon         = "/icon/docker.svg"
  run_on_start = true
  script       = <<-EOT
    #!/bin/bash
    set -euo pipefail
    echo "Waiting for Docker daemon..."
    until docker info > /dev/null 2>&1; do
      sleep 1
    done
    echo "Docker is ready."
  EOT
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.main.name
  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DOCKER_HOST=tcp://${docker_container.dind.name}:2375",
  ]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  networks_advanced {
    name = docker_network.private_network.name
  }
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
