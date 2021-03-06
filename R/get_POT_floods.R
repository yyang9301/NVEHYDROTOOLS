#' @title Extracting POT-values for a set of stations
#' @description Use independence criterion based on Lang et al (1999)
#' @description See 'get_pot' for deitals on how independent POT values are extracted
#' @description Should first extract AMS values to get the years to be used for extracting POT data
#' @param amsfile file with annual maximum data. Only years with ams will be used
#' @param dailydata  folder with daily data
#' @param p_threshold the thershold for selecting flood values given as emprical quantile of all data
#' @param TTR_3X The minimum time between two independent flood peaks
#' @param pratio The minimum flow between two flood peaks should be less than pratio times the first flood peak.
#' @param outfile The file for storing ams values
#' @return data frame with reginenumber, main number, flood date, flod size, thershold. for all stations.
#' The dataframe is written to the specified outfile.
#' @export
#'
#' @examples extract_pot_allstations(amsfile='inst/Example_data/Flooddata/amsvalues.txt',
#' dailydata="inst/Example_data/Dailydata",
#' p_threshold = 0.98, TSEP = 6,pratio= 2.0/3.0,
#' outfile="inst/Example_data/Flooddata/potvalues.txt")
#'

extract_pot_allstations<-function(amsfile='inst/Example_data/Flooddata/amsvalues.txt',
                                  dailydata="inst/Example_data/Dailydata",
                                  p_threshold = 0.98, TSEP = 6,pratio= 2.0/3.0,
                                  outfile="inst/Example_data/Flooddata/potvalues.txt"){



  floods<-read.table(amsfile, header=TRUE,sep=";")
  stationnumbers=floods$regine*100000+floods$main

  sn_unique<-unique(floods$regine*100000+floods$main)
  mypot<-NA
  for(i in 1:length(sn_unique)){
# First extract years from the AMS file
    f_years<-unique(as.numeric(format(as.Date(floods$daily_ams_dates[stationnumbers==sn_unique[i]]), "%Y")))
# Then get the POT floods.

    mypot_temp<-get_pot(snumb=sn_unique[i],f_years=f_years,path_dd=dailydata,
                        p_threshold=p_threshold,TSEP=TSEP,pratio=pratio)

    if(i==1|is.na(mypot)) mypot<-mypot_temp
    else if(!is.na(mypot_temp))mypot<-rbind(mypot,mypot_temp)
  }
  write.table(mypot,file=outfile,row.names=FALSE,sep=";")
  return(mypot)
}
#' @title Extract independent POT values for one station
#' @description Use independence criterion based on Lang et al (1999)
#' @description The following calculation steps are used:
#' @description  1: Find the threshold T based on the pecentile P from the observed daily data
#' @description  2: Find all values abouve the thershold and identify in which direction the threshold is crossed
#' @description  3: Find maximums of all clusters above thershold. A cluster is all values between an upward and a downward crossing.
#' @description  4: Find the number of days between each maximum from 3
#' @description  5: If data are separated by less than TTR*3, select the maximum. TTR is 'time to rize'. See Lang et al (1999)
#' @description  6: Find the minimum flow between two flood events
#' @description  7: if the minimum flow is higher than 2/3 of the first flood, then select the two
#' @description  10.06.2016, LESC (lena schlichting)
#' @param snumb Station number accordin to NVE: rrmmmmm where r is reine  number and m is main number
#' @param f_years Vectors of years that should be used. If NA, all years in the data file will be used
#' @param path_dd  Folder with daily data
#' @param p_threshold The thershold for selecting flood values given as a precentile
#' @param TTR_3X The minimum time between two independent flood peaks
#' @param pratio The minimum flow between two flood peaks should be less than pratio times the first flood peak.
#'
#' @return data frame with reginenumber, main number, flood date, flod size, thershold for the station specified by snumb.
#' @export
#'
#' @examples extract_pot_allstations(amsfile='inst/Example_data/Flooddata/amsvalues.txt',
#' dailydata="inst/Example_data/Dailydata",
#' p_threshold = 0.98, TTR_3x = 6,pratio= 2.0/3.0,
#' outfile="inst/Example_data/Flooddata/potvalues.txt")
#
get_pot<-function(snumb=200011,f_years=NA,path_dd="inst/Example_data/Dailydata",
                  p_threshold=0.98, TSEP = 6,pratio= 2./3.){

  reginenr=as.integer(snumb/100000)
  mainnr=snumb-reginenr*100000
  myfiles_day <- list.files(path_dd)
  snumbers_day <- as.integer(substr(myfiles_day,1,nchar(myfiles_day)-4))
  loc_day <- which(snumb==snumbers_day)
  if(length(loc_day) ==0)return(NA)
  #load in daily series
  else{
    dailydat <- read.table(paste(path_dd,'/',myfiles_day[loc_day], sep=""),sep=" ")
    colnames(dailydat) <- c("orig_date", "vf")
    dailydat$date <- as.Date(dailydat$orig_date, format = "%Y%m%d")
    dailydat$year <-  as.numeric(format(as.Date(dailydat$date), "%Y"))
    #set -9999 as NA
    dailydat[dailydat == -9999] <- NA
    daily_years <- as.numeric(na.omit(unique(dailydat$year)))

# use only the selected years
    if(!is.na(f_years))dailydat<-dailydat[is.element(dailydat$year,f_years),]

# Get the quantile used as threshold
    qt<-quantile(as.numeric(dailydat[,2]),p_threshold,na.rm=TRUE)

# find alle data abpove the thershold
    above<-dailydat[,2]>qt

# find times when the threshold is crossed
    intersect.points<-which(diff(above)!=0)
#    intersect.points[which(above[intersect.points]==FALSE)]

# find up and down crossings over the thershold
    up.cross<-intersect.points[!above[intersect.points]]+1
    down.cross<-intersect.points[above[intersect.points]]
# If number of down crossings is larger than the number of up-crossings, the time series start with a flood event.
# This event is excluded since we do not know if we get the maximum peak.
    if(length(down.cross)>length(up.cross))down.cross<-down.cross[2:length(down.cross)]

    # If number of up crossings is larger than the number of up-crossings, the time series ends with a flood event.
    # This event is excluded since we do not know if we get the maximum peak.
    if(length(down.cross)<length(up.cross))up.cross<-up.cross[1:(length(up.cross)-1)]
    

# Internal function for extracting flood peaks. To be used with sapply
    get_floodpeaks<-function(ii){
      fevent<-dailydat[up.cross[ii]:down.cross[ii],]
      if(any(is.na(fevent[,2]))) {
        pflood=NA
        pflood_date=NA
      }
      else {
        pflood=max(fevent[,2])
        pflood_date=fevent[which(pflood==fevent[,2]),3][1]
      }
      return(list(pflood,pflood_date))
    }

# Extract flood peaks as the maximums of a bunch of data above the threshold
    flood_peaks<-sapply(c(1:length(up.cross)),get_floodpeaks,simplify=TRUE)
    flood_dates<-as.Date(unlist(flood_peaks[2,]),origin = "1970-01-01")
    flood_peaks<-as.numeric(unlist(flood_peaks[1,]))

# Select independent floods that are separated by at least 6 days:
# first calculate the time lags between successive floods
    gapLengths = c(1000, diff(flood_dates))
# The group events that are separated by less than TRR_3x days to the same cluster
    clusterNumbers = cumsum(gapLengths > TSEP)

# internal function to extract maximum values and dates
    get_cmax<-function(xx){
      return(as.character(xx[which.max(xx[,2]),])  )
    }

# Get the maximum values for each cluster
    floods_indep<-by(data=cbind(flood_dates,flood_peaks),INDICES=clusterNumbers,FUN = get_cmax)
    floods_matrix<-matrix(as.numeric(unlist(floods_indep)),ncol=2,byrow=TRUE)


#cluster daily data between flood peaks
    bclusters<-bclusters<-cumsum(as.numeric(dailydat[,3])%in%floods_matrix[,1])

#Find the minimum in each cluster between two successive flood peaks
    minbetween<-as.numeric(by(dailydat[,2],bclusters,min,na.rm=TRUE))
    minbetween<-minbetween[2:length(minbetween)]

#Find the new clusters so that two floods where the minimum streamflow between
#them is higher than 2/3 of the firts peak, belongs to the same event
    nb=length(minbetween)-1
    fclusters<-cumsum(c(1,floods_matrix[1:nb,2])*pratio>c(0,minbetween[1:nb]))
# Find the maximum of these new clusters
    floods_indep_2<-by(data=floods_matrix,INDICES=fclusters,FUN = get_cmax)

# Wrap it into a matrix that is returned
    floods_matrix_2<-matrix(as.numeric(unlist(floods_indep_2)),ncol=2,byrow=TRUE)
return(data.frame(regine=reginenr,main=mainnr,date=as.Date(floods_matrix_2[,1],origin = "1970-01-01"),
             flood=as.numeric(floods_matrix_2[,2]),threshold=qt))
}
}

