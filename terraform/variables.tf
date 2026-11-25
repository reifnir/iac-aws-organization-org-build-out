variable "project_url" {
  description = "URL of the GitLab project that deploys this module (GitLab's CI_PROJECT_URL). Used for the Project URL default tag."
  type        = string
  nullable    = false
}

variable "gitlab_token" {
  description = "GitLab token with api scope and Owner of reifnir-public-projects and reifnir-private-projects, for managing their CI/CD variables."
  type        = string
  nullable    = false
  sensitive   = true
  ephemeral   = true
}
