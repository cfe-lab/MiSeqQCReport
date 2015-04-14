#!/usr/bin/env Rscript

library(R2HTML)
library(Cairo)
source(file="westgard.R")

###############################################################################
# Settings/constants                                                          #
###############################################################################

# Absolute paths to make this R script launchd / crontab friendly
currPath = "./"
scriptName = "2_generate_report.R"

# Customization.
clusterdensity.min <- 500
clusterdensity.max <- 1200

# Plot settings.
plotWidth <- 800
plotHeight <- 500
plotColor <- c("black", "forestgreen")
plotType <- "o"
plotLwd <- 2
plotPch <- c(16, 17)
flagColor <- c("red", "red")
flagPch <- c(1, 17)
plotColumns <- 3
plotRows <- 2

# Westgard rules in use (defined in westgard.R).
westgardRules <- c(westgard.1_3s, westgard.2_2s, westgard.4_1s, westgard.R4s, westgard.10x)

###############################################################################
# Data-related/utility functions                                              #
###############################################################################

westgard <- function (x) {
    z <- standardize(x)
    Reduce("|", lapply(westgardRules, function (rule) rule(z)))
}

# Format a number for display in a table.
table.format <- function (n) {
    formatC(n, format="f", digits=2)
}

# Scale down outliers which are more than dev.max standard deviations
# away from the mean.
shrink.outliers <- function(x, dev.max) {
    xmean <- mean(x)
    xsd <- sd(x)
    xmin <- xmean - dev.max*xsd
    xmax <- xmean + dev.max*xsd
    x[x < xmin] <- xmin
    x[x > xmax] <- xmax
    x
}


###############################################################################
# Plotting-related functions                                                  #
###############################################################################

# Add circles to indicate points have been flagged.
flag.points <- function (x, y, flags, pch, col) {
    points(x[flags], y[flags], pch=pch, cex=2, lwd=2, col=col)
}

# Add reference lines for different standard deviation values
lines.mean.sd <- function (y) {
    my.mean <- mean(y)
    my.sd <- sd(y)
    abline(h=my.mean, lwd=2)
    abline(h=my.mean + my.sd, lty="dotted", lwd=2, col="green3")
    abline(h=my.mean - my.sd, lty="dotted", lwd=2, col="green3")
    abline(h=my.mean + 2*my.sd, lty="longdash", lwd=2, col="darkgoldenrod1")
    abline(h=my.mean - 2*my.sd, lty="longdash", lwd=2, col="darkgoldenrod1")
    abline(h=my.mean + 3*my.sd, lwd=2, col="red")
    abline(h=my.mean - 3*my.sd, lwd=2, col="red")
}

###############################################################################
# HTML-related functions                                                      #
###############################################################################

# Make an HTML image map for a scatterplot.
make.image.map <- function (x, y, titles, map.name) {
    x.dev <- as.integer(grconvertX(x, to="device"))
    y.dev <- as.integer(grconvertY(y, to="device"))

    html <- c(paste0('<map name="', map.name, '">'))
    areas <- apply(cbind(x.dev, y.dev, titles), 1, function (row) {
        sprintf('<area shape="circle" coords="%s,%s,5" title="%s" nohref>', 
                row[1], row[2], row[3])
    })
    html <- c(html, areas)
    c(html, "</map>")
}

# Make an HTML list of items
make.html.list <- function (items) {
    c("<ul>", paste0("<li>", items, "</li>"), "</ul>")
}

###############################################################################
# Read and process data                                                       #
###############################################################################

# Read the CSV file (dump of MiSeqQC_RunParameters JOIN MiSeqQC_InteropSummary).
args<-commandArgs(TRUE)
if (length(args) != 2) { stop(paste("Syntax: ./", scriptName, " <csvFile> <outpath>", sep="")) }
filePath <- args[1]
fileName <- gsub(".csv", "", basename(filePath))
reportDir <- args[2]
data <- read.csv(filePath, header=TRUE)

# Read list of parameters (name,desc,unit).
param.list <- read.csv("parameter_list.csv", header=T, stringsAsFactors=F)
rownames(param.list) <- param.list$parameter
param.list$ylab <- with(param.list, 
                        ifelse(!is.na(param.unit),
                               paste0(param.desc, " (", param.unit, ")"), 
                               param.desc))

# Read list of reagents (name,desc).
reagent.list <- read.csv("reagent_list.csv", header=T, stringsAsFactors=F)
rownames(reagent.list) <- reagent.list$reagent

# Parse dates.
data$RUNSTARTDATE <- as.Date(data$RUNSTARTDATE, "%d-%b-%y")
expiration.cols <- paste0(reagent.list$reagent, "_EXPIRATION")
data[,expiration.cols] <- lapply(data[,expiration.cols], as.Date, format="%d-%b-%y")

# Collect missing runs, and remove from further analysis.
missing.runs <- data[is.na(data$RUNID.1),]
data <- data[!is.na(data$RUNID.1),]

# Change proportions to percentages.
data$Q30_1 <- data$Q30_1*100
data$Q30_2 <- data$Q30_2*100

# Apply Westgard rules.
flags <- apply(data[,param.list$parameter], 2, westgard)
colnames(flags) <- paste0(colnames(flags), ".FLAG")
data <- cbind(data, flags)

# Number of days until expiration dates.
reagent.cols <- paste0(reagent.list$reagent, "_EXPIRATION")
days.left <- lapply(data[,reagent.cols], function(col) as.numeric(col-Sys.Date()))
names(days.left) <- sub("_EXPIRATION", ".DAYSLEFT", names(days.left))
data <- cbind(data, days.left)

# Create alerts.
# Runs missing from QC tables.
alerts <- apply(missing.runs, 1, function (row) {
    sprintf("Sample sheet created on %s has no associated QC data", row["RUNNAME"],
            strftime(row["RUNSTARTDATE"], "%b %d, %Y"))
})
# Parameters flagged on most recent run.
flag.cols <- colnames(data)[grepl("[.]FLAG$", colnames(data))]
most.recent <- data[nrow(data), flag.cols]
most.recent <- most.recent[,which(t(most.recent))]
alerts <- c(alerts, sapply(names(most.recent), function (col) {
    sprintf("Parameter %s has been flagged",
            sub(".FLAG", "", col, fixed=T))
}))
# Reagents which are about to expire or have already expired.
expire.cols <- colnames(data)[grepl("[.]DAYSLEFT$", colnames(data))]
most.recent <- data[nrow(data), expire.cols]
most.recent <- most.recent[,which(t(most.recent) < 31)]
alerts <- c(alerts, sapply(names(most.recent), function (col) {
    sprintf("The %s will expire in %d days",
            sub(".DAYSLEFT", "", col, fixed=T),
            most.recent[,col])
}))

###############################################################################
# Make plots                                                                  #
###############################################################################

x <- data$RUNSTARTDATE
xlab <- "run date"
point.labels <- strftime(data$RUNSTARTDATE, "%b %d, %Y")

nup <- plotRows*plotColumns
nplots <- as.integer(nrow(param.list)/(nup))+1
. <- sapply(seq(0, nplots-1), function (i) {
    params <- param.list[(i*nup+1):(i*nup+nup),"parameter"]
    params <- params[!is.na(params)]
    plotName <- paste0("parameters", i, ".png")
    CairoPNG(file.path(reportDir, plotName), width=plotWidth, height=plotHeight)
    par(yaxs="i", mfrow=c(plotRows, plotColumns), mar=c(2, 2, 1, 1), oma=c(1, 1, 0, 4))
    sapply(1:length(params), function (i) {
        y <- data[,params[i]]
        flag <- data[,paste0(params[i], ".FLAG")]
        ylim <- c(mean(y)-4*sd(y), mean(y)+4*sd(y))
        y.scaled <- shrink.outliers(y, 4)
        title <- param.list[params[i],"ylab"]
        plot(x, y.scaled, ylim=ylim, type="n")
        lines.mean.sd(y)
        points(x, y.scaled, type=plotType, pch=plotPch[1], col=plotColor[1], lwd=plotLwd,
                 xlab=NA, ylab=NA, ylim=ylim)
        flag.points(x, y.scaled, flag, flagPch[1], flagColor[1])
        if (i %% plotColumns == 0 | i == length(params)) {
            axis(4, at=mean(y)+sd(y)*seq(-3, 3), labels=seq(-3, 3))
        }
        
        limits <- par("usr")
        xmiddle <- (limits[1] + limits[2])/2
        ymax <- limits[4]
        text(xmiddle, ymax, title, font=2, cex=1.5, pos=1)
    })
    mtext("standard deviations from mean", side=4, outer=T, line=2)
    dev.off()
})

image.maps <- c()

# Report 1: Cluster Density
CairoPNG(file.path(reportDir, "REPORT-1.png"), 
    width=plotWidth, height=plotHeight, bg="transparent")
y <- data$CLUSTERDENSITY
ymin <- min(c(clusterdensity.min, y))
ymax <- max(c(clusterdensity.max, y))
plot(x, y, type=plotType, pch=plotPch[1], col=plotColor[1], lwd=plotLwd,
     ylim=c(ymin, ymax), xlab=xlab, ylab=param.list["CLUSTERDENSITY","ylab"])

flag <- data$CLUSTERDENSITY.FLAG
flag.points(x, y, flag, flagPch[1], flagColor[1])
flag <- y > clusterdensity.max | y < clusterdensity.min
flag.points(x, y, flag, flagPch[2], flagColor[2])

abline(h=clusterdensity.min, lty="longdash", lwd=3)
abline(h=clusterdensity.max, lty="longdash", lwd=3)
text(max(x), clusterdensity.min, labels=clusterdensity.min, pos=3, cex=1.5)
text(max(x), clusterdensity.max, labels=clusterdensity.max, pos=3, cex=1.5)

title(main="Cluster density")
grid(nx=0, ny=NULL, col="black")
legend(par("usr")[2], par("usr")[4], xjust=1, yjust=0, xpd=T,
       legend=c("Tolerance", "Flagged (Westgard)", "Flagged (outside tolerance)"),
       lty=c("longdash", NA, NA), pch=c(NA, flagPch), col=c("black", flagColor))
image.maps <- c(image.maps, make.image.map(x, y, point.labels, "REPORT1Map"))
dev.off()


# Report 2: % bases passing Q30 cutoff
CairoPNG(file.path(reportDir, "REPORT-2.png"), 
    width=plotWidth, height=plotHeight, bg="transparent")
par(yaxs="i")
q30.means <- c(mean(data$Q30_1), mean(data$Q30_2))
q30.stdevs <- c(sd(data$Q30_1), sd(data$Q30_2))
ymin <- min(q30.means-4*q30.stdevs)
ymax <- max(c(q30.means+4*q30.stdevs, 100))

y <- data$Q30_1
flag <- data$Q30_1.FLAG
plot(x, y, type=plotType, col=plotColor[1], lwd=plotLwd, pch=plotPch[1],
     ylim=c(ymin, ymax), ylab="bases passing Q30 cutoff (%)", xlab=xlab)
flag.points(x, y, flag, flagPch[1], flagColor[1])

y <- data$Q30_2
flag <- data$Q30_2.FLAG
lines(x, y, type=plotType, pch=plotPch[2], col=plotColor[2], lwd=plotLwd)
flag.points(x, y, flag, flagPch[1], flagColor[1])

title(main="Bases passing Q30 cutoffs")
grid(nx=0, ny=NULL, col="black")
legend(par("usr")[2], par("usr")[4], xjust=1, yjust=0, xpd=T,
       legend=c("read 1", "read 2", "Flagged (Westgard)"), 
       col=c(plotColor, flagColor[1]), pch=c(plotPch, flagPch[1]))
image.maps <- c(image.maps, make.image.map(c(x, x), c(data$Q30_1, data$Q30_2), 
                                           c(point.labels, point.labels), 
                                           "REPORT2Map"))
dev.off()

# Finally, generate the report.
Sweave("report.Rnw", driver=RweaveHTML, syntax="SweaveSyntaxNoweb")
