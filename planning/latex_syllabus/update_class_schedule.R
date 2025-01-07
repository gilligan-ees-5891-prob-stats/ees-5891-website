library(tidyverse)
library(lubridate)
library(DBI)


d0 <- ymd('2025-01-07') # first day of classes

src <- src_sqlite('../ees-5891.sqlite3')
calendar <- tbl(src, 'calendar')

new_calendar <- calendar %>% collect() %>%
  mutate(date = d0 + - 2 + days(2 * (cal_id %% 3) + 7 * (cal_id %/% 3))) %>%
  mutate(date = as.character(date))

con <- dbConnect(RSQLite::SQLite(), "../ees-5891.sqlite3")
dbWriteTable(con, "calendar", new_calendar, overwrite = TRUE)
