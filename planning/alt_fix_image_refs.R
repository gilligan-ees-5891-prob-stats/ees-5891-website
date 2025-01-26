fix_img_files <- function(base_dir) {
  files <- list.files(base_dir, pattern = "*.Rmd", recursive = TRUE)

  for (f in files) {
    b <- str_replace(basename(f), "\\.Rmd$", "")
    f <- file.path(base_dir, f)
    d <- dirname(f)
    text <- read_file(f)
    m <- str_match_all(text,
                       "!\\[[^\\]]+\\]\\((?<fname>[^ )]+)( .*)?\\)") |>
      map(~.x[,'fname']) |>
      unlist()
    if (length(m) > 0) {
      new_path <- file.path(d, b)
      if (! dir.exists(new_path)) {
        dir.create(new_path)
      }
      missing_files <- list()
      for (x in m) {
        dest_dir <- file.path(new_path, dirname(x))
        if (! dir.exists(dest_dir)) {
          dir.create(dest_dir, recursive = TRUE)
        }
        file_src <- file.path(d, x)
        file_dest <- file.path(new_path, x)
        if (file.exists(file_src)) {
          do_copy <- ! file.exists(file_dest)
          if (! do_copy) {
            src_info <- file.info(file_src)
            dest_info <- file.info(file_dest)
            do_copy <- isTRUE(src_info$size != dest_info$size) ||
              isTRUE(src_info$mtime != dest_info$mtime)
          }
          if (do_copy) {
            message("Copying ", file_src, " to ", file_dest)
            file.copy(file_src, file_dest)
          }
        } else {
          missing_files <- c(missing_files,
                             list(list(ref = b, file = file_src,
                                       spec = x)))
        }
      }
    }
  }
}
