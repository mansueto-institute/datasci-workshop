# Introduction to R Shiny
Materials for the introduction to R Shiny Workshop

To follow along open the [slides here.](https://docs.google.com/presentation/d/1fuUIlfagMGkDzUlRQxjIImjY7mxgqqmS335MYzTqNbc/edit?usp=sharing) Here is a [gallery](https://shiny.rstudio.com/gallery/) of Shiny app examples. 

## How to run the Shiny app in 5 steps:
1. Install R [here](https://cran.r-project.org/).
2. Install R Studio [here](https://www.rstudio.com/products/rstudio/download/).
3. Open R Studio and install necessary packages:
```
install.packages('shiny')
install.packages('tidyr')
install.packages('ggplot2')
install.packages('dplyr')
```
4. Copy [app.R](https://raw.githubusercontent.com/rcc-uchicago/r-shiny-intro-workshop/master/app.R) code into new R Script.
5. Click `Run App`.

And to deploy the app on [shinyapps.io](https://www.shinyapps.io/) run the following line of code:
```
# install.packages('rsconnect')
library(rsconnect)

# First, create an account on shinyapps.io and run the following:
# rsconnect::setAccountInfo(name='user_name',
#                           token='user_token',
#                           secret='user_secret')

# Second, deloy app (make sure to put the app.R file in a local R Project directory called 'intro-to-shiny-project')
rsconnect::deployApp('~/intro-to-shiny-project')

# The web link to the deployed app will automatically launch in your browser
```
To display the app alongside the code use the following function:
```
runApp(display.mode = "showcase")
```

## Author
Nicholas Marchio (contact: nmarchio at uchicago.edu)

## Credits
The presentation and portions of code were based on RStudio tutorial [materials](https://shiny.rstudio.com/tutorial/) developed by Garrett Grolemund.
