variable "project_url" {
  description = "URL of the GitLab project that deploys this module (GitLab's CI_PROJECT_URL). Used for the Project URL default tag."
  type        = string
  nullable    = false
}
