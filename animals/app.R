#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Animals"),

    actionButton("animal", "Show me an animal")
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    observeEvent(input$animal, {
        session$sendCustomMessage(type = 'testmessage',
                                  message = 'Animal!')
})
}
# Run the application 
shinyApp(ui = ui, server = server)
