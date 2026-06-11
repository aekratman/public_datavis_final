Code - All web site files and libraries assuming they are not too big to include

Data - Include all the data that you used in your project. If the data is too large for github store it on a cloud storage provider, such as Dropbox or Yousendit.
(Find the Data in the assault_clean CSV!)

Process Book- Your Process Book in PDF format.

README - The README file must give an overview of what you are handing in: which parts are your code, which parts are libraries, and so on. The README must contain URLs to your project websites and screencast videos. The README must also explain any non-obvious features of your interface.


** Project Webpage **: https://aekratman.shinyapps.io/grad-final/
NOTE: If shinyapps is not working, you can run the project locally by using the command shiny::runApp() !

** Screencast **: Find it over on youtube at https://youtube.com/@aekratman

Our code was primarily written in R, then using the Shiny App library to transfer R to a readable and interactive webpage. We used many other libraries to help make the visualizations sleek and interactive. These libraries include:

* Leaflet, for allowing our graphs to show against a real map of Chicago.
* GGplot2 & plotly: To make the visualizations clean using skills from previous assignments.
* Lubridate, dplyr,readr, sf, and tidycensus: To make the process of writing in R using time and census data more simple.

These libraries were invaluable. 

We built several visualizations:
1.) Cluster Map; This graph shows clusters of data. Clicking on each cluster allows you to zoom in, and see the individual data points-- specifically what crimes they pull from.
2.) Heat Map; This graph maps heat to the quantity of assaults commited. Zoom in to interact with it.
3.) Population vs. Crime Rate Analysis; This graph compares each census tract to the rate of crime it experiences.


We built a few different basic trend trackers and started analyzing them:
1.) Time of Day; This graph splits crimes between the daytime (yellow) and nighttime (purple). 
2.) Arrest Trends; This graph is a simple trend tracker with hoverable data points. Click on them to see their year and quantity
3.) Severity Map; This graph compared aggravated (red) to non-aggravated (orange) assaults. 

The time analysis and arrest trend graphs were left on the final product to showcase the analysis we did, but we decided not to use the severity and time maps as they felt cluttered and unclear. 

Thus, we implemented the severity tracker into another population rate graph. 

INTERFACE NOTE: All of the interactive visualizations above are zoomable and can be clicked on for more information. Each tab must be clicked to bring the user to the tab of their choosing.

We also included the base code of building a local LLM to analyze the crime trends of recent years in the llmwork.r file.

Thank you!