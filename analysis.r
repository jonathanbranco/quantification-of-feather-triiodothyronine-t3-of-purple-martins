#Libraries ----
library(tidyverse)
library(cowplot)
library(AICcmodavg)

# Open and rename data ----
data <- read.csv("dataset.csv")
data <- rename(data,
               "ID" = Sample.ID,
               "Hg" = Hg..ug.g.,
               "T3" = T3..pg.mg.,
               "Corticosterone" = Corticosterone..pg.mg.)

# Histograns ----
ggplot(data, aes(x = Hg))+
  geom_histogram(bins = 30)+
  labs(x="Concentration of THg (ug/g)",y="Number of samples")+
  theme_classic() -> hg_hist
ggplot(data, aes(x = log10(Corticosterone)))+
  geom_histogram(bins = 30)+
  labs(x="Concentration of corticosterone (log10 pg/mg)",y="Number of samples")+
  theme_classic() -> cort_hist
ggplot(data, aes(x = T3))+
  geom_histogram(bins = 30)+
  labs(x="Concentration of T3 (pg/mg)",y="Number of samples")+
  theme_classic()-> t3_hist

cowplot::plot_grid(hg_hist,cort_hist,t3_hist, ncol=1) -> hist_plots


min_t3 <- min(data$T3)
max_t3 <- max(data$T3)
mean_t3 <- mean(data$T3)
sd_t3 <- sd(data$T3)
se_t3 <- sd_t3/sqrt(length(data$T3))


# Statistical models ----
  lm_t3_hg <- lm(T3~Hg,data = data)
  lm_t3_cort <- lm(T3~log10(Corticosterone),data = data)
  lm_t3_sex <- lm(T3~Sex,data = data)
  lm_t3_location <- lm(T3~Location,data = data)
  lm_t3_sex_location <- lm(T3~Sex+Location,data = data)
  lm_t3_cort_location <- lm(T3~log10(Corticosterone)+Location,data = data)
  lm_t3_hg_location <- lm(T3~Hg+Location,data = data)
  lm_t3_null <- lm(T3~1,data = data)
  
  candidates_T3 <- list("THg" = lm_t3_hg,
                        "Corticosterone (log10)" = lm_t3_cort,
                        "Sex" = lm_t3_sex,
                        "Breeding location" = lm_t3_location,
                        "Sex + breeding location" = lm_t3_sex_location,
                        "Corticosterone (log10) + breeding location" = lm_t3_cort_location,
                        "THg + breeding location" = lm_t3_hg_location,
                        "Null" = lm_t3_null)
  
  aictab_t3 <- aictab(cand.set = candidates_T3) #Breeding location selected
  
  # Add residual error to table and removes LL
  candidates_T3 <- candidates_T3[match(aictab_t3[,1], names(candidates_T3))]
  aictab_t3 <- select(aictab_t3, -"LL")
  for(i in 1:length(candidates_T3)){
  aictab_t3$StdResErr[i] <- summary(candidates_T3[[i]])$sigma
  }
  
  # Estimates of selected model and CI
  estimates <- summary(lm_t3_location)$coefficients[,"Estimate"]
  
  n <- 79
  
    CI95 <- function(n, est, sd){
      names(est) <- NULL
      return(c(est - 1.96*(sd/sqrt(n)), est + 1.96*(sd/sqrt(n))))
    }
  
    # 95% CI Florida
    CI_fl <- CI95(n,
                  estimates[1],
                  sd(filter(data, Location == "Florida")$T3))
    
    # 95% CI Virginia
    CI_va <- CI95(n,
                  estimates[1]+estimates[2],
                  sd(filter(data, Location == "Virginia")$T3))
    
    # 95% CI Wisconsin
    CI_wi <- CI95(n,
                  estimates[1]+estimates[3],
                  sd(filter(data, Location == "Wisconsin")$T3))
  
# Plotting figures of predictive models ----
  # Breeding model
  ggplot(data, aes(x=Location, y=T3))+
    geom_boxplot()+
    geom_text(aes(x=Inf,y=Inf),
              label=paste("ΔAICc:", round(aictab_t3[aictab_t3$`Modnames`=="Breeding location","Delta_AICc"],2), "\n",
                          "Model likelihood:", round(aictab_t3[aictab_t3$`Modnames`=="Breeding location","ModelLik"],2), "\n",
                          "Model weight:", round(aictab_t3[aictab_t3$`Modnames`=="Breeding location","AICcWt"],2), ""), 
              hjust="right", vjust="top", fontface="bold")+
    labs(x="Breeding location", y="Feather T3 (pg/mg)")+
    theme_classic() -> t3_location_boxplot
  
#Exporting results ----
  #Prepares and exports aictab
  for(tab in c("aictab_t3")){
    assign(tab,
           as_tibble(get(tab))) #Turns aictabs into tibbles to facilitate changes
    assign(tab,
           cbind(get(tab)[1:2], #Gets columns 1 and 2 as normal
                 round(as_tibble(get(tab))[3:8],2))) #Rounds columns 3 to 8 up to 2 decimal points
    assign(tab,
           rename(get(tab), 'Predictors' = Modnames, "ΔAICc" = Delta_AICc, "CumWt" = Cum.Wt)) #Renames columns
    write.csv(get(tab), paste("Tables/",tab,".csv",sep=""), row.names=F) #Exports aictabs
  }
  
  #Exports plots
  ggsave("Figures/hist_plot.png", plot=hist_plots, width = 6, height=6, dpi="print")
  ggsave("Figures/t3_location_boxplot.png", plot=t3_location_boxplot, width = 6, height=4, dpi="print")
  