variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI"
  type        = string
}

variable "anthropic_oauth_token" {
  type        = string
  description = "Long-lived OAuth token for Claude Code (starts with sk-ant-oat01-...). Generate with `claude setup-token`."
  sensitive   = true
  default     = ""
}

# URL of your Coder server. Used by the workspace agent to communicate back.
# Set this in Template Settings → Variables; it should match your CODER_URL.
variable "coder_agent_url" {
  type        = string
  description = "Base URL of the Coder deployment (e.g. http://192.168.1.100:3000). Must be reachable from inside the workspace container."
  default     = ""
}
