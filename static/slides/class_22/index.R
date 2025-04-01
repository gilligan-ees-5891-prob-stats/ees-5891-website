## ----setup, cache = F, echo = F, eval = T, message=F, warning=F-----------------------------------------------------------------------------------------------------------------------------------------------
knitr::opts_chunk$set(cache=TRUE,
                      echo=FALSE, message=FALSE, warning=FALSE,
                      fig.height=9, fig.width=14, dpi=100,
                      dev="png", dev.args = list(type = "cairo-png"),
                      fig.path='assets/fig/',cache.path='./cache/')

library(rprojroot)

semester_dir <- find_rstudio_root_file()
data_dir <- file.path(semester_dir, "data")
climate_data_dir <- file.path(semester_dir, "climate_data")
script_dir <- file.path(semester_dir, "lecture_scripts")
climate_script_dir <- file.path(script_dir, "climate_scripts")
local_script_dir <- file.path("assets", "scripts")

source_semester_script <- function(script) {
  script_file <- file.path(script_dir, script)
  message("Running script", script_file)
  source(script_file, chdir = T)
}

source_climate_script <- function(script) {
  script_file <- file.path(climate_script_dir, script)
  message("Running script", script_file)
  source(script_file, chdir = T)
}

eval_in_sem_script_dir <- function(expr, loc = script_dir) {
  this_dir <- getwd()
  setwd(loc)
  retval <- eval(expr)
  setwd(this_dir)
  invisible(retval)
}

library(knitr)
library(qrcode)
library(magrittr)
library(tidyverse)
library(scales)
library(GGally)
library(tidymodels)
library(patchwork)

theme_set(theme_bw(base_size = 20))


## ----eval=TRUE, include=FALSE---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
gh_class_url <- "https://classroom.github.com/a/"
qr <- qr_code(gh_class_url)
generate_svg(qr, "assets/images/qrcode.svg", show = FALSE)


## ----logit-plot, echo=FALSE, fig.height=9, fig.width=9--------------------------------------------------------------------------------------------------------------------------------------------------------
df_p <- tibble(
  p = seq(0.001, 0.999, length.out = 200),
  x = LaplacesDemon::logit(p)
)
df_x <- tibble(
  x = seq(-5, 5, length.out = 200),
  p = LaplacesDemon::invlogit(x)
)

p1 <- ggplot(df_p, aes(x = p, y = x)) +
  geom_line() +
  scale_y_continuous(breaks = seq(-5, 5, 5)) +
  labs(x = "p", y = expression(logit(p)), title = "Logit function")

p2 <- ggplot(df_x, aes(x = x, y = p)) +
  geom_line() +
  labs(x = "x", y = expression({logit^-1} (x)), title = "Inverse-logit function")

p1 / p2


## ----load-bh-data, echo=FALSE---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
bh <- read_rds(file.path(data_dir, "bh.rds"))


## ----echo=TRUE, eval=FALSE------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# bh <- read_rds("bh.rds")

## ----set-width-55, echo=FALSE, cache = FALSE------------------------------------------------------------------------------------------------------------------------------------------------------------------
old_width <- getOption("width")
options(width = 55)

## ----echo=TRUE, dependson="load-bh-data", cache.extra= getOption("width")-------------------------------------------------------------------------------------------------------------------------------------
glimpse(bh)

## ----reset-width, echo=FALSE, cache = FALSE-------------------------------------------------------------------------------------------------------------------------------------------------------------------
options(width = old_width)


## ----boxplot-bh, echo=FALSE, dependson="load-bh-data", fig.width=9, fig.height=4------------------------------------------------------------------------------------------------------------------------------
ggplot(bh, aes(x = FirstLat, y = Type)) +
  geom_boxplot(notch = TRUE, linewidth = 1, staplewidth = 0.1,
               outlier.color = "darkblue", outlier.fill = "darkblue",
               outlier.size = 3, outlier.alpha = 1) +
  geom_point(color = "darkblue", alpha = 0.1, size = 3) +
  labs(x = expression(paste("Formation Latitude ", (degree * N))),
       y = NULL)


## ----make-log-workflow, echo=TRUE, dependson="load-bh-data"---------------------------------------------------------------------------------------------------------------------------------------------------
recipe <- recipe(bh, Type ~ FirstLat)
model <- logistic_reg() |>
  set_engine("glm", family = "binomial")
wflow <- workflow(recipe) |> add_model(model)
results <- wflow |> fit(data = bh)

## ----inspect-log-fit, echo=TRUE, dependson="make-log-workflow"------------------------------------------------------------------------------------------------------------------------------------------------
tidy(results)


## ----plot-binom-fit, dependson="make-log-workflow"------------------------------------------------------------------------------------------------------------------------------------------------------------
pred <- tibble(FirstLat = seq(min(bh$FirstLat), max(bh$FirstLat),
                              length.out = 100))
pred <- pred |>
  mutate(prob = predict(results, new_data = pred, type = "prob"),
         se = predict(results, new_data = pred, type = "conf_int")) |>
  unnest(c(prob,se))
ggplot(bh, aes(x = FirstLat)) +
  geom_jitter(aes(y = ifelse(Type == "Baroclinic", 1, 0)),
              size = 2, alpha = 0.5, height = 0.01) +
  geom_ribbon(data = pred, aes(ymin = .pred_lower_Baroclinic,
                               ymax = .pred_upper_Baroclinic),
              fill = "darkblue", alpha = 0.1) +
  geom_line(data = pred, aes(y = .pred_Baroclinic),
            color = "darkblue", linewidth = 1) +
  labs(x = expression(paste("Origin Latitude ", (degree * N))),
       y = "Probability Baroclinic") +
  scale_y_continuous(labels = label_percent(1))


## ----gen-roc, echo=TRUE, dependson="make-log-workflow"--------------------------------------------------------------------------------------------------------------------------------------------------------
set.seed(12345)
# strata=Type ensures that each fold has a good balance of
# Tropical and Baroclinic cyclones.
k_fold <- vfold_cv(bh, 5, strata = Type)
control <- control_resamples(save_pred = TRUE)

results <- fit_resamples(wflow, k_fold, control = control)

## ----ref.label="set-width-55", echo=FALSE, cache=FALSE--------------------------------------------------------------------------------------------------------------------------------------------------------

## ----analyze-roc, echo=TRUE, dependson="gen-roc"--------------------------------------------------------------------------------------------------------------------------------------------------------------
results |> collect_predictions() |> glimpse()

## ----ref.label="reset-width", echo=FALSE, cache=FALSE---------------------------------------------------------------------------------------------------------------------------------------------------------


## ----show-auc, echo=TRUE, dependson="gen-roc"-----------------------------------------------------------------------------------------------------------------------------------------------------------------
results |> collect_metrics() |> filter(.metric == "roc_auc")


## ----plot-roc, echo=TRUE, dependson="gen-roc", fig.width=5, fig.height=5--------------------------------------------------------------------------------------------------------------------------------------
results |> collect_predictions() |>
  roc_curve(truth = Type, .pred_Baroclinic,
            event_level = "second") |>
  autoplot() +
  scale_x_continuous(expand = c(0,0)) +
  scale_y_continuous(expand = c(0,0))


## ----load-hurricanes, echo=FALSE------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
hurricanes <- read_rds(file.path(data_dir, "hurricanes.rds"))


## ----echo=TRUE, eval=FALSE------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# hurricanes <- read_rds("hurricanes.rds")

## ----ref.label="set-width-55", cache=FALSE--------------------------------------------------------------------------------------------------------------------------------------------------------------------

## ----echo=TRUE, dependson="load-hurricanes"-------------------------------------------------------------------------------------------------------------------------------------------------------------------
glimpse(hurricanes)

## ----ref.label="reset-width", caceh=FALSE---------------------------------------------------------------------------------------------------------------------------------------------------------------------


## ----echo=FALSE, dependson="load-hurricanes", fig.width=8, fig.height=4---------------------------------------------------------------------------------------------------------------------------------------
ggplot(hurricanes, aes(x = Year, y = All)) +
  geom_col(fill = alpha("blue", 0.2), color = "darkblue") +
  labs(x = "Year", y = "# hurricanes")

## ----echo=FALSE, dependson="load-hurricanes", fig.width=8, fig.height=4---------------------------------------------------------------------------------------------------------------------------------------
ggplot(hurricanes, aes(x = All)) +
  geom_histogram(binwidth = 1, fill = alpha("blue", 0.2),
                 color = "darkblue") +
  labs(x = "# hurricanes", y = "# years")


## ----plot-landfalls-vs, dependson="load-hurricanes", fig.width = 9, fig.height = 9----------------------------------------------------------------------------------------------------------------------------
hurricanes |> select(All, NAO, SOI, SST, SSN) |>
  pivot_longer(cols = c(NAO, SOI, SST, SSN),
               names_to = "index", values_to = "value") |>
  mutate(All = ordered(All)) |>
  summarize(mean = mean(value), sd = sd(value),
            .by = c("All", "index")) |>
  ggplot(aes(x = mean, xmin = mean - sd, xmax = mean + sd, y = All)) +
  geom_pointrange(size = 1, color = "darkblue") +
  labs(y = "Hurricane Count") +
  facet_wrap(~index, scales = "free_x")


## ----pois-reg-setup, echo=TRUE, dependson="load-hurricanes"---------------------------------------------------------------------------------------------------------------------------------------------------
library(poissonreg)
rec <- recipe(hurricanes, All ~ SST + NAO + SOI + SSN)
mdl <- poisson_reg(engine = "glm")
wflow <- workflow(rec) |> add_model(mdl)

## ----fit-poisson, echo=TRUE, dependson="pois-reg-setup"-------------------------------------------------------------------------------------------------------------------------------------------------------
fit <- fit(wflow, hurricanes)

## ----pois-reg-res, echo=TRUE, dependson="fit-poisson"---------------------------------------------------------------------------------------------------------------------------------------------------------
tidy(fit)


## ----pois-fit-new, echo=TRUE----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
rec_new <- recipe(hurricanes, All ~ NAO + SOI + SSN)
wflow_new <- workflow(rec_new) |> add_model(mdl)
fit_new <- fit(wflow_new, hurricanes)


## ----new-pois-fit-res, echo=TRUE, dependson="pois-fit-new"----------------------------------------------------------------------------------------------------------------------------------------------------
tidy(fit_new)


## ----poisson-cv, echo=TRUE, dependson="pois-reg-setup"--------------------------------------------------------------------------------------------------------------------------------------------------------
k_fold <- vfold_cv(hurricanes, 5)
control <- control_resamples(save_pred = TRUE)
results <- fit_resamples(wflow_new, k_fold, control = control)

## ----pois-cv-res, echo=TRUE, dependson="poisson-cv"-----------------------------------------------------------------------------------------------------------------------------------------------------------
results |> collect_metrics()


## ----naive-model, echo=TRUE, dependson="load-hurricanes"------------------------------------------------------------------------------------------------------------------------------------------------------
MSE_naive <- hurricanes |>
  summarize(MSE = sum( (All - mean(All))^2 ) / (n() - 1)) |>
  pull(MSE)

MSE_naive


## ----MSE-mdl, echo=TRUE, dependson="pois-cv-res"--------------------------------------------------------------------------------------------------------------------------------------------------------------
MSE_skilled <- collect_metrics(results) |>
  filter(.metric == "rmse") |>
  mutate(MSE = mean^2) |> pull(MSE)
MSE_skilled

