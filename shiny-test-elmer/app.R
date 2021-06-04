library(shiny)
library(shinythemes)
library(data.table)
library(tidyverse)
library(DT)
library(odbc)
library(DBI)

## Read from Elmer

db.connect <- function() {
    elmer_connection <- dbConnect(odbc(),
                                  Driver = "SQL Server",
                                  Server = "AWS-PROD-SQL\\Sockeye",
                                  Database = "sandbox",
                                  # Trusted_Connection = "yes"
                                  UID = Sys.getenv("userid"),
                                  PWD = Sys.getenv("pwd")
    )
}

read.dt <- function(astring, type =c('table_name', 'sqlquery')) {
    elmer_connection <- db.connect()
    if (type == 'table_name') {
        dtelm <- dbReadTable(elmer_connection, SQL(astring))
    } else {
        dtelm <- dbGetQuery(elmer_connection, SQL(astring))
    }
    dbDisconnect(elmer_connection)
    setDT(dtelm)
}


ui <- fluidPage(
numericInput("nrows", "Enter the number of person table rows to display:", 5),
DTOutput("tbl"),
numericInput("person_in", "Enter the person_id of the record you want to change", 19100000101),
numericInput("time_in","What value would you like to enter for commute_auto_time", 30),
DTOutput("newdata")
)

server <- function(input, output, session) {
    
    output$tbl <- renderDT({
        sql.query <- paste("SELECT TOP ", toString(input$nrows)," ", " person_id, household_id, survey_year, age, gender, commute_auto_time 
                           FROM Suzanne.persons_test
                           WHERE commute_auto_time >0 AND person_id>0 AND household_id>0")
        person_data<- read.dt(sql.query, 'sqlquery')})

    output$newdata <- renderDT({
    sql.query_update <- paste("UPDATE Suzanne.persons_test SET commute_auto_time=",toString(input$time_in),
                       " WHERE person_id=", toString(input$person_in))
    read.dt(sql.query_update, 'sqlquery')
    sql.query_new_vals <- paste("SELECT person_id, household_id, survey_year, age, gender, commute_auto_time FROM Suzanne.persons_test WHERE person_id=", toString(input$person_in))
    new_values<- read.dt(sql.query_new_vals, 'sqlquery')})
}


shinyApp(ui, server)