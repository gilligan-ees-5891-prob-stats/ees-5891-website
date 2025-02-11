library(rprojroot)
library(tidyverse)
pacman::p_load_gh("jonathan-g/blogdownDigest")
pacman::p_load_gh("jonathan-g/semestr")
#library(credentials)
library(gert)
# library(git2r)

if (file.exists("fix_image_refs.R")) {
  source("fix_image_refs.R")
} else {
  source("planning/fix_image_refs.R")
}

regenerate_site <- function(root = NULL, force = FALSE) {
  if (is.null(root)) {
    root = find_root(criterion = has_file(".semestr.here"))
  }
  oldwd = setwd(root)
  on.exit(setwd(oldwd))
  message("Setting working directory to ", getwd())
  semester <- load_semester_db("planning/EES-5891.sqlite3")
  generate_assignments(semester)
  fix_image_refs(list.dirs("content", recursive = FALSE))
  new_update_site(root = getwd(), force = force)
}

new_update_site <- function(root = NULL, force = FALSE) {
  if (is.null(root)) {
    root = find_root(criterion = has_file(".semestr.here"))
  }
  oldwd = setwd(root)
  on.exit(setwd(oldwd))
  message("Setting working directory to ", getwd())
  update_site(force = force)
  out_opts = list(md_extensions = semestr:::get_md_extensions(), toc = TRUE,
                  includes = list(in_header = "ees5891.sty"))
  update_pdfs(force_dest = TRUE, force = force, output_options = out_opts)
}

publish <- function(ssh = NULL, repo = ".") {
  git_push("origin", "refs/heads/main")
  git_push("publish", "refs/heads/main")
}
