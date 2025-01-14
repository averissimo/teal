testthat::test_that("srv_teal_with_splash data accepts a teal_data_module", {
  testthat::expect_no_error(
    shiny::testServer(
      app = srv_teal_with_splash,
      args = list(
        id = "id",
        data = teal_data_module(ui = function(id) div(), server = function(id) reactive(NULL)),
        modules = modules(example_module())
      ),
      expr = {}
    )
  )
})

testthat::test_that("srv_teal_with_splash throws when teal_data_module doesn't return reactive", {
  testthat::expect_error(
    shiny::testServer(
      app = srv_teal_with_splash,
      args = list(
        id = "id",
        data = teal_data_module(ui = function(id) div(), server = function(id) NULL),
        modules = modules(example_module())
      ),
      expr = {}
    ),
    "The `teal_data_module` must return a reactive expression."
  )
})

testthat::test_that("srv_teal_with_splash teal_data_rv evaluates the server of teal_data_module", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data_module(ui = function(id) div(), server = function(id) reactive("whatever")),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_is(teal_data_rv, "reactive")
      testthat::expect_identical(teal_data_rv(), "whatever")
    }
  )
})

testthat::test_that("srv_teal_with_splash passes teal_data to reactive", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data(iris = iris),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_is(teal_data_rv_validate, "reactive")
      testthat::expect_s4_class(teal_data_rv_validate(), "teal_data")
    }
  )
})

testthat::test_that("srv_teal_with_splash throws when datanames are empty", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data(),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_error(teal_data_rv_validate(), "Data has no datanames")
    }
  )
})

testthat::test_that("srv_teal_with_splash teal_data_rv_validate throws when teal_data_module returns error", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data_module(
        ui = function(id) div(),
        server = function(id) reactive(stop("this error"))
      ),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_is(teal_data_rv_validate, "reactive")
      testthat::expect_error(teal_data_rv_validate(), "this error")
    }
  )
})

testthat::test_that("srv_teal_with_splash teal_data_rv_validate throws then qenv.error occurs", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data_module(
        ui = function(id) div(),
        server = function(id) reactive(teal_data() %>% within(stop("not good")))
      ),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_is(teal_data_rv_validate, "reactive")
      testthat::expect_error(teal_data_rv_validate(), "not good")
    }
  )
})

testthat::test_that(
  "srv_teal_with_splash teal_data_rv_validate throws when teal_data_module doesn't return teal_data",
  {
    shiny::testServer(
      app = srv_teal_with_splash,
      args = list(
        id = "test",
        data = teal_data_module(
          ui = function(id) div(),
          server = function(id) reactive(data.frame())
        ),
        modules = modules(example_module())
      ),
      expr = {
        testthat::expect_is(teal_data_rv_validate, "reactive")
        testthat::expect_error(teal_data_rv_validate(), "did not return `teal_data`")
      }
    )
  }
)


testthat::test_that("srv_teal_with_splash creates raw_data based on DDL returns NULL before loading", {
  x <- dataset_connector(dataname = "test_dataset", pull_callable = callable_code("iris"))
  delayed_data <- teal_data(x)
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = delayed_data,
      modules = modules(example_module())
    ),
    expr = testthat::expect_null(raw_data())
  )
})

testthat::test_that("srv_teal_with_splash creates raw_data based on DDL returns pulled data when loaded", {
  teal.logger::suppress_logs()
  x <- dataset_connector(dataname = "iris", pull_callable = callable_code("iris"))
  delayed_data <- teal_data(x)
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = delayed_data,
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_null(raw_data())
      session$setInputs(`startapp_module-submit` = TRUE) # DDL has independent session id (without ns)
      testthat::expect_is(raw_data(), "teal_data")
      testthat::expect_identical(raw_data()[["iris"]], iris)
    }
  )
})

testthat::test_that("srv_teal_with_splash teal_data_rv_validate throws when incompatible module's datanames", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data(mtcars = mtcars),
      modules = modules(example_module(datanames = "iris"))
    ),
    expr = {
      testthat::expect_is(teal_data_rv_validate, "reactive")
      testthat::expect_error(
        teal_data_rv_validate(),
        "Module 'example teal module' uses datanames not available in 'data'"
      )
    }
  )
})

testthat::test_that("srv_teal_with_splash teal_data_rv_validate returns teal_data if incompatible filter's datanames", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data(mtcars = mtcars),
      modules = modules(example_module(datanames = "mtcars")),
      filter = teal_slices(teal_slice(dataname = "iris", varname = "Species"))
    ),
    expr = {
      testthat::expect_is(teal_data_rv_validate, "reactive")
      testthat::expect_s4_class(teal_data_rv_validate(), "teal_data")
    }
  )
})

testthat::test_that("srv_teal_with_splash gets observe event from srv_teal", {
  shiny::testServer(
    app = srv_teal_with_splash,
    args = list(
      id = "test",
      data = teal_data(),
      modules = modules(example_module())
    ),
    expr = {
      testthat::expect_is(res, "Observer")
    }
  )
})
