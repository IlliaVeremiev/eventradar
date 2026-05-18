# Admin proxy — hidden coder_app that establishes the subdomain
# admin--<workspace>--<owner>--coder.panikjor.dev and forwards every
# path to http://localhost:8000 (Laravel). Hidden because the button
# is provided by admin_link below, which opens a specific subpath.
resource "coder_app" "admin" {
  agent_id  = coder_agent.main.id
  slug      = "admin"
  url       = "http://localhost:8000"
  subdomain = true
  share     = "owner"
  hidden    = true

  healthcheck {
    url       = "http://localhost:8000"
    interval  = 10
    threshold = 30
  }
}

# Admin Preview button — external link that navigates the browser to
# the proxied admin subdomain. Update the path to match your admin route.
resource "coder_app" "admin_link" {
  agent_id     = coder_agent.main.id
  slug         = "admin-open"
  display_name = "Admin"
  url          = "https://${local.admin_host}/admin"
  icon         = "/icon/php.svg"
  external     = true
  open_in      = "tab"
  order        = 3
}

# API subdomain proxy — hidden, used by the frontend as VITE_CODER_API_URL.
# Points to the same Laravel server (port 8000) via its own slug.
resource "coder_app" "api" {
  agent_id  = coder_agent.main.id
  slug      = "api"
  url       = "http://localhost:8000"
  subdomain = true
  share     = "owner"
  hidden    = true
}

# Vite dev server (port 5173) for Laravel's asset pipeline.
# Hidden — Laravel's vite.config.js references this via VITE_DEV_SERVER_* env vars.
resource "coder_app" "vite" {
  agent_id  = coder_agent.main.id
  slug      = "vite"
  url       = "http://localhost:5173"
  subdomain = true
  share     = "owner"
  hidden    = true
}

# Frontend app (eventradar-ui, port 5174).
resource "coder_app" "frontend" {
  agent_id     = coder_agent.main.id
  slug         = "frontend"
  display_name = "Frontend"
  url          = "http://localhost:5174"
  icon         = "/icon/nodejs.svg"
  subdomain    = true
  share        = "owner"
  open_in      = "tab"
  order        = 4

  healthcheck {
    url       = "http://localhost:5174"
    interval  = 10
    threshold = 30
  }
}
