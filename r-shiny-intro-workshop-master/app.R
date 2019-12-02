# Demo of k-means clustering app
# Nicholas Marchio 07/2019
# Based on RStudio materials here https://www.dropbox.com/s/rjt6g3ctdqvihat/shiny-quickstart-1.zip
# Code here: https://github.com/rcc-uchicago/r-shiny-intro-workshop
# Slides here: https://docs.google.com/presentation/d/1fuUIlfagMGkDzUlRQxjIImjY7mxgqqmS335MYzTqNbc/edit

# Global environment ------------------------------------------------------
# Put all code that runs on startup in the Global i.e. libraries, functions, pre-loaded data, etc.

library(shiny)
library(tidyr)
library(ggplot2)
library(dplyr)

color_list <- c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3","#FF7F00", "#FFFF33", "#A65628", "#F781BF", "#999999") # Color hexes

data(iris) # Load dataframe
pca <- as.data.frame(prcomp(log(iris[, 1:4]),center = TRUE,scale. = TRUE)[["x"]]) %>% select(PC1, PC2) # Run PCA
iris <- merge(iris, pca, by=0, all=TRUE) %>% select(-one_of(c('Row.names'))) # Merge iris with 2 components

# User Interface ----------------------------------------------------------

# Construct the user interface object
ui <- fluidPage(
  headerPanel('Iris k-means Clustering Tool'), 
  sidebarPanel(
    selectInput(inputId = 'xcol', label = 'X Variable', choices = names(iris)[names(iris) != "Species"]), # Input widget for X-axis column 
    selectInput(inputId = 'ycol', label = 'Y Variable', choices = names(iris)[names(iris) != "Species"], selected = names(iris)[[2]]),  # Input widget for Y-axis column 
    sliderInput(inputId = 'clusters', label = 'Cluster count', value = 3, min = 1, max = 9),  # Input widget for number of clusters 
    radioButtons(inputId = "labels", label = "Cluster labels", choices = c("k-means" = "kmeans_label","Actual" = "actual_label")) # Radio button to toggle between clusters and actual labels
  ),
  mainPanel(
    plotOutput(outputId = 'xyplot') # Render plot output
  )
)

# Server ------------------------------------------------------------------

# Construct the server object
server <- function(input, output, session) {
  
  # Reactives that contain data selected from the input widgets
  selectedData <- reactive({iris[, c(input$xcol, input$ycol)]})
  selectedX <- reactive({iris[, c(input$xcol)]})
  selectedY <- reactive({iris[, c(input$ycol)]})
  
  # Reactive that runs k-means clustering function on SelectedData() reactive
  clusters <- reactive({
    kmeans(x = selectedData(), centers = input$clusters) # Run k-means clustering
  })
  
  # Reactive value that contains the legend's cluster groupings
  grouping <- reactiveValues()
  
  # Observe event to adjust the number of clusters (and update the radio button to reflect selection)
  observeEvent(input$clusters, {
    if(input$labels=="kmeans_label" | (input$labels=="actual_label" & input$clusters != 3)) { 
      grouping$data <- as.factor(clusters()$cluster) # Assign k-means clusters to data
    }
    updateRadioButtons(session, inputId = 'labels', selected = if(length(unique(grouping$data)) == 3 & input$labels=="actual_label") {"actual_label"} else {"kmeans_label"} ) # Update radio button
  })
  
  # Observe event to change between 'k-means' and 'Actual' radio buttons (and update the slider if 'Actual' is selected)
  observeEvent(input$labels, {
    if(input$labels=="actual_label") {grouping$data <- iris$Species} # Assign actual species clusters to data
    else { grouping$data <- as.factor(clusters()$cluster) } # Assign k-means clusters to data
    updateSliderInput(session, inputId = 'clusters', value = length(unique(grouping$data)) ) # Update value to correspond to the number of clusters in the legend
  })
  
  # Render a plot of the reactive data as an output object
  output$xyplot <- renderPlot({
    # Create X-Y scatter plot
    ggplot(data=iris) + # Iris dataset
      geom_point(aes_string(x=selectedX(), # Reactive for x input widget
                            y=selectedY(), # Reactive for y input widget
                            color=grouping$data), # Reactive for legend's cluster groupings
                 size = 4, alpha = .8) + 
      scale_color_manual(values = color_list, name = NULL, guide = guide_legend(nrow = 1)) + # Assign color palette from global
      xlab(input$xcol) + ylab(input$ycol) + #
      theme_minimal() +
      theme(text = element_text(size=20),
            legend.position = 'bottom')
  })
}

# Shiny Object ------------------------------------------------------------

# Create Shiny app objects based on ui and server objects
shinyApp(ui = ui, server = server)
