setwd("~/git/R-projects/csv-stats")
library(RCurl)
library(stringr)
library(ggplot2)
library(scales)
library(data.table)
theme_set(theme_minimal(base_family = "Helvetica Neue"))
options(stringsAsFactors = FALSE)
options(RCurlOptions = list(timeout = 5, maxredirs = 1))
source("~/git/R-projects/data-portal-analysis/functions.r")
source('~/git/R-projects/ODI-colours.R')

### Note to self: I AM USING DATA TABLE
# data.table is lower case, may not be convention
gov <- as.data.table(read.csv("/Users/Ulrich/git/csv_finder/csv_urls.csv", na.strings = ""))
# Count missing values, count empty fields, count unique entries
sapply(gov, no.missing)
sapply(gov, count.empty)
sapply(gov, count.unique)
sapply(gov, pct.unique)

# Count how many csv-files actually have a URL ending in .csv
table(str_detect(gov$url, "csv$"))
#FALSE  TRUE >> 3929 16763 
table(str_detect(gov$url, "^http"))
#FALSE  TRUE >> 8 20684
table(str_detect(gov$url, "^https"))
#FALSE  TRUE >> 17169  3523

# Create csv only file
gov.csv <- gov[which(str_detect(gov$url, "csv$")), ]

# Size statistics and chart
summary(gov.csv$size)
ggplot(data = gov.csv, aes(x = size/1000)) + geom_histogram(fill = odi_lGreen, color = "white") + 
  scale_x_log10(labels = comma) + xlab("Size in kb") +
  theme(axis.title.x = element_text(hjust = 0.4))
ggsave(file="graphics/histogram-size-of-csvs.png", height = 2, width = 8, dpi = 100)

# Test whether URL exists
pb <- txtProgressBar(min = 1, max = nrow(gov.csv), style = 3)
for (i in 1:nrow(gov.csv)) {
  temp <- try(url.exists(gov.csv[i, url]))
  gov.csv[i, exists:=temp]
  setTxtProgressBar(pb, i)
}
close(pb)

# Percentages
table(gov$exists)
formatC( table(gov$exists) / nrow(gov) * 100, digits = 3)
table(gov.csv$exists)
formatC( table(gov.csv$exists) / nrow(gov.csv) * 100, digits = 3)

# Now option for data.table's fread
read.url <- function(url, func = "read.csv", ...){
  if (func %ni% c("read.csv", "fread")) stop("Function not recognised")
  temporaryFile <- tempfile()
  download.file(url, destfile = temporaryFile, method = "curl", quiet = TRUE)
  if (func == "read.csv") url.data <- read.csv(temporaryFile, ...)
  if (func == "fread") url.data <- fread(temporaryFile, ...)
  return(url.data)
}

# Error with wrong number of skip? (No, suspect only in exceptional circumstances)
read.url(gov[1, url], nrow = 5, skip = 4)

# fread random test - produces better header names
read.url(gov[1819, url], func = "read.csv", nrows = 5)
names(read.url(gov[1819, url], func = "read.csv", nrows = 5))
names(read.url(gov[1819, url], func = "fread", nrows = 5))

# Collection of some errors
# curl: (60) SSL certificate problem: Invalid certificate chain
# curl: (6) Could not resolve host:  http
# curl: (56) Recv failure: Connection reset by peer
# Error in make.names(col.names, unique = TRUE) : invalid multibyte string at '<a3>25K<20>EXPENDITURE APRIL 2013'
# Redirects [1819] http://www.chre.org.uk/_img/pics/library/Copy_of_101018__CO_guidance_salary_disclosure_mgt_team.csv

# ------------------------------
# Loop over csv URLs while trying to count the errors
# Filter out unresponsive URLs
setkey(gov.csv, exists)
gov.csv.exist <- gov.csv[J(TRUE)]
# Set silent = FALSE to show error messages.
pb <- txtProgressBar(min = 0, max = nrow(gov.csv.exist), style = 3)
for (i in 1:nrow(gov.csv.exist)) {
  temp <- try(read.url(gov.csv.exist[i, url], func = "fread", nrow = 2, skip = 0),  silent = TRUE)
  if(inherits(temp, "try-error")) tempbool <- 1
  else tempbool <- 0
  gov.csv.exist[i, error:=tempbool]
  setTxtProgressBar(pb, i)
}
close(pb)

table(gov.csv.exist$error)

