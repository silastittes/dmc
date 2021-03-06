# Generation of variance/covariance matrices (F^(S)) under
#	different modes of convergent adaptation
#
# This script uses functions saved in genSelMatrices_fxns.R
#
# Args to be provided below:
#	rec: per base pair recombination rate estimate for the region
#	F_estimate: estimate of neutral variance/covariance matrix
#		generated with "calcNeutralF.R"
#	Ne: effective population size estimate
#	numPops: number of populations sampled (both selected and non-selected)
#	positions: vector of genomic positions for region of interest
#	sampleSizes: vector of sample sizes (# chromosomes sampled) of length numPops + same order of populations as F_estimate 
#
#	*Parameter spaces for likelihood calculations*
#	selSite: vector of positions of proposed selected sites
#	sels: vector of proposed selection coefficients
#	intro_times: vector of proposed time in generations the variant is standing 
#		in populations after migration and before selection occurs
# stdVar_times: vector of proposed time in generations the variant is standing 
#		in populations after selected populations split and before selection occurs
#	gs: vector of proposed frequencies of the standing variant
#	migs: vector of proposed migration rates (proportion of individuals from source each generation)
#		*Note: cannot be 0

### Load/assign all arguments for functions ###
# "type" is the way we chose which pops to include in the model
Version="J"
type="6P-new" #"6P-old"
#set working directory to load objects in the corresponding "type" folder
setwd(paste("~/Documents/grandis/objects",Version,type,sep="/"))
F_estimate=readRDS("neutralF.RDS")
sampleSizes=readRDS("sampleSizes.RDS")
numPops=length(sampleSizes)
pops=colnames(F_estimate)
positions=readRDS("target_freqs.RDS")$pos

## Categorize neutral sites into bins of distances to the selected site.
# Selection matrices will be generated for each bin, with the midpoint of 
# the distances included in the bin as the representative distance used to 
# estimate recombination rates between neutral and selected site.
# Since we only have 1 selected site here, we can just get one vector 
# of the distance of each position to the selected site.
selSite = (718209 + 807159)/2 # using midpoint of deletion breakpoints that are furthest from each other
saveRDS(selSite,paste("~/Documents/grandis/objects",Version,"selSite.RDS",sep="/"))
distances = abs(positions-selSite)
##bin distances
numBins = 1000
my.seq = seq(min(distances) - 0.001, max(distances) + 0.001, length.out = (numBins + 1))
midDistances = sapply(1:numBins, function(i) mean(c(my.seq[i], my.seq[i+1]))) # representative distances for each bin

# recombination rate
rec = readRDS(paste("~/Documents/grandis/objects",Version,"rec_rate.RDS",sep="/"))

# assign Ne estimates in a vector, with each element index corresponding to population with that index in neutral F matrix
Ne=rep(NA,length(pops))
Ne[which(grepl("h",pops))] = 2.25e6 # Ne for heteroclitus pops (who all have "h" in population name)
Ne[which(grepl("g",pops))] = 8.1e5 # Ne for grandis pops (who all have "g" in population name)

# get indeces of neutral F matrix rows/columns (which will be modified to get selection matrix)
# of selected and non-selected populations
selPops = which(grepl("2",pops)) #populations with "2" in name are homozygous for deletion & thus selected pops
nonSelPops = seq(1, numPops)[- selPops] #all other pops do not experience sweep


## Proposed parameter vectors
# save all of the below proposed parameters to be used again in computing likelihoods & plotting results
setwd(paste("~/Documents/grandis/objects",Version,sep="/"))

sels = c(0.001, 0.005, seq(0.01, 0.05, by = 0.01), seq(0.06, 0.2, by = 0.02), seq(0.3,0.8,by=0.1), seq(0.82,1,by=0.02))
saveRDS(sels,"sels.RDS")
times = c(seq(0,15,by=5),seq(16,30,by=2),35,seq(40,100,by=20),200,500, 1000, 5000, 10e6)
saveRDS(times,"times.RDS")
stdVar_times = c(3e3, 4e3, 5e3,7.5e3,9e3,1e4,2.5e4,5e4, 10^(5:8))
saveRDS(stdVar_times,"stdVar_times.RDS")
gs = c(1/(2*Ne[which(grepl("g2",pops))]), 8.5e-7,1e-6,2e-6,5e-6,8e-6,10^(-(5:2))) # starting with lowest possible freq 1/2N is resistant grandis pop
saveRDS(gs,"gs.RDS")
migs = c(0.00001, 0.0001, 0.0005, 0.001, 0.005, 0.01, 0.1, 0.3)
saveRDS(migs,"migs.RDS")

## Modify resulting matrices for inference procedure

sampleErrorMatrix = diag(1/sampleSizes, nrow = numPops, ncol = numPops)

# Mean centering
M = numPops
Tmatrix = matrix(data = rep(-1 / M, (M - 1) * M), nrow = M - 1, ncol = M)
diag(Tmatrix) = (M - 1) / M 

## Load all functions saved in genSelMatrices_fxns.R
prob_no_rec_out=readRDS("prob_no_rec_out.RDS")
calctotAddF_stdVar=readRDS("calctotAddF_stdVar.RDS")
calcFOmegas_stdVar=readRDS("calcFOmegas_stdVar.RDS")
calctotAddF_stdVar.source=readRDS("calctotAddF_stdVar_source.RDS")
calcFOmegas_stdVar.source=readRDS("calcFOmegas_stdVar_source.RDS")
calctotAddF_mig.stagSweeps=readRDS("calctotAddF_mig_stagSweeps.RDS")
calcFOmegas_mig.stagSweeps=readRDS("calcFOmegas_mig_stagSweeps.RDS")
calctotAddF_mig.concSweeps=readRDS("calctotAddF_mig_concSweeps.RDS")
calcFOmegas_mig.concSweeps=readRDS("calcFOmegas_mig_concSweeps.RDS")


## Get probability of recombining out of sweep ahead of time for each parameter combination
## since similar results are used among the modes of convergent adaptation

# when starting frequency for sweep is 1/2N 
# returns vector of length numPops (because pops have different 1/2N starting values)
ys.ind = lapply(sels, function(sel) {
  lapply(rec*midDistances, function(Rec) {
    sapply(Ne,function(N) {
      prob_no_rec_out(x=1/(2*N),s=sel,r=Rec)
    })
  })
})

# when starting frequency for sweep is frequency of the standing variant
# returns one value (not a vector like for ys.ind)
ys.stand = lapply(sels, function(sel) {
  lapply(gs, function(G) {
    lapply(rec*midDistances, function(Rec) {prob_no_rec_out(x=G,s=sel,r=Rec)})
  })
})

## Set working directory to save selection matrices, to be read in calcInvDetSelMatrices.R
## Note: from here on we call selection matrices 'FOmegas'
setwd(paste("~/Documents/grandis/objects",Version,type,sep="/"))

## Implemenation: Standing Variant Model (ILS)
# free parameters: sels, gs, std_var times
FOmegas_stdVar = lapply(sels, function(S) {
  lapply(gs, function(g) {
    lapply(stdVar_times, function(t_m){
      calcFOmegas_stdVar(sel=S,G=g,time=t_m)
    })
  })
})
saveRDS(FOmegas_stdVar,file="FOmegas_stdVar.RDS")

## All below models are different introgression scenarios, each with the given source and recipient populations
source=which(pops=="ER_h2") # source pop has to be selected  
recipient=which(pops=="VB_g2") # recipient pop has to be selected 

## Implementation : Standing Variant Source Model
# free parameters: sels, gs, times
FOmegas_stdVar.source = lapply(sels, function(S) {
  lapply(gs, function(g) {
    lapply(times, function(Time) {
      calcFOmegas_stdVar.source(sel=S,G=g,time=Time)
    })
  })
})
saveRDS(FOmegas_stdVar.source,file="FOmegas_stdVar_source.RDS")

## Implementation: Staggered Sweeps Model
# free parameters: sels, gs, times
FOmegas_mig.stagSweeps = lapply(sels, function(S) {
  lapply(gs, function(g) {
    lapply(times, function(t_m){
      calcFOmegas_mig.stagSweeps(sel=S,G=g,standing.time=t_m)
    })
  })
})

saveRDS(FOmegas_mig.stagSweeps, file="FOmegas_mig_stagSweeps.RDS")

## Implementation: Concurrent Sweeps Model
# free parameters: sels, migs
FOmegas_mig.concSweeps = lapply(sels, function(S) {
  lapply(migs, function(M) {
    calcFOmegas_mig.concSweeps(sel=S,mig=M)
  })
})
saveRDS(FOmegas_mig.concSweeps, file="FOmegas_mig_concSweeps.RDS")
