# http://www.westgard.com/mltirule.htm
standardize <- function (x) {
    (x-mean(x))/sd(x)
}

# x is a boolean vector
# replace all runs of TRUE in x which are shorter than minlen with FALSE
conseq.trues <- function (x, minlen) {
    r <- rle(x)
    r$values <- r$values & r$lengths >= minlen
    inverse.rle(r)
}

# In each of the rule functions, z is assumed to be standardized,
# that is, z is a vector of standard deviations away from the mean.

westgard.1_3s <- function (z) {
    abs(z) > 3
}

westgard.1_2s <- function (z) {
    abs(z) > 2
}

westgard.2_2s <- function (z) {
    conseq.trues(z > 2, 2) | conseq.trues(z < -2, 2)
}

westgard.R4s <- function (z) {
    d <- abs(diff(z)) > 4
    s <- diff(sign(z)) > 0
    conseq.trues((c(d, F) | c(F, d)) & (c(F, s) | c(s, F)) & abs(z) > 2, 2)
}

westgard.3_1s <- function (z) {
    conseq.trues(z > 2, 3) | conseq.trues(z < -2, 3)
}

westgard.4_1s <- function (z) {
    conseq.trues(z > 2, 4) | conseq.trues(z < -2, 4)
}

westgard.8x <- function (z) {
    conseq.trues(z > 0, 8) | conseq.trues(z < 0, 8)
}

westgard.10x <- function (z) {
    conseq.trues(z > 0, 10) | conseq.trues(z < 0, 10)
}

westgard.12x <- function (z) {
    conseq.trues(z > 0, 12) | conseq.trues(z < 0, 12)
}
