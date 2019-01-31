library(shiny)
library(reticulate)
library(DT)
#low_memory = false


person_variables <- read.csv('person_variables.csv')

ui <- shinyUI(
  pageWithSidebar(
    headerPanel('Travel Survey Crosstab Generator'),
    sidebarPanel(
      # point to data directory

      selectInput('xcol', 'First Dimension', person_variables),
      selectInput('ycol', 'Second Dimension', person_variables),
      actionButton('go', 'Create Crosstab'),
      downloadButton("downloadData", "Download")
    ),
    mainPanel(
      tableOutput("table")
    )
  )
)



server <- function(input, output, session) {
  

  source_python('travel_crosstab.py')
  type <- 'total'
  wt_field <- 'hh_wt_revised'
  
  observeEvent(input$go,{
  crosstab<-cross_tab(input$xcol,input$ycol,wt_field, type)
  output$table = renderTable({crosstab})
  output$downloadData <- downloadHandler(
    filename = function() {
      paste(c(input$xcol, input$ycol), ".csv", sep = "")
    },
    content = function(con) {
      write.csv(crosstab, con)
    })
  }
  )
   
  
  # Downloadable csv of selected dataset ----
 

  
}


shinyApp(ui= ui, server=server)