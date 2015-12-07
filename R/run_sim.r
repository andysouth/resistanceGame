#' run simulation of population and resistance change
#'
#' initially accepts single arg values next get it to accept vectors by time
#'
#' @param num_tsteps number of timesteps to run simulation
#' @param pop_start start vector population
#' @param resist_freq_start frequency of resistance at start, 0 to 1
#' @param rate_growth population growth rate
#' @param carry_cap carrying capacity (K) in the logistic model
#' @param rate_insecticide_kill kill rate due to insecticide
#' @param resistance_modifier modifies effect of resistance
# @param insecticide_on whether insecticide is applied 0=no, 1=yes
# @param resistance_on whether there is resistance to the applied insecticide 0=no, 1=yes
#' @param resist_incr increase in resistance when correct insecticide present
#' @param resist_decr decrease in resistance when correct insecticide absent
#' @param use_pyr use pyrethroids NA for no, 1 for yes, or a vector e.g. c(NA,1) to give alternate use
#' @param use_ddt use ddt see use_pyr
#' @param use_ops use organophosphates see use_pyr
#' @param use_car use carbamates see use_pyr
#' @param randomness 0-1 0=none, 1=maximum
#' 
#' @examples
#' dF <- run_sim_oldest(pop_start=0.5, resist_freq_start=0.2, rate_growth=0.4, carry_cap=1, rate_insecticide_kill=0.4, resistance_modifier=1)
#' #plot default run
#' plot_sim_oldest( run_sim_oldest())
#' #modify params
#' plot_sim_oldest( run_sim_oldest( rate_insecticide_kill = 0.3, resist_incr = 0.05 ))
#' #alternate use of pyr
#' plot_sim_oldest( run_sim_oldest(use_pyr=c(NA,1)))
#' @return dataframe of simulation results
#' @export

run_sim_oldest <- function(num_tsteps=20,
                    pop_start=0.5,
                    resist_freq_start=0.1,
                    rate_growth=0.2,
                    carry_cap=1,
                    rate_insecticide_kill=0.2,
                    resistance_modifier=1,
                    #insecticide_on=1,
                    #resistance_on=1,
                    resist_incr = 0.2,
                    resist_decr = 0.1,
                    use_pyr = rep(1,num_tsteps),
                    use_ddt = NA,
                    use_ops = NA,
                    use_car = NA,
                    randomness = 0
) 
{

  dF <- init_sim_oldest(num_tsteps)

  dF$pop[1] <- pop_start
  dF$resist_pyr[1] <- resist_freq_start

  dF$use_pyr <- use_pyr
  dF$use_ddt <- use_ddt
  dF$use_ops <- use_ops
  dF$use_car <- use_car
  
  #tstep loop
  for( tstep in 1:(num_tsteps-1) )
  {
    
    #cat("t",tstep,"\n")
    
    insecticide_on <- dF$use_pyr[tstep] | dF$use_ddt[tstep] | dF$use_ops[tstep] | dF$use_car[tstep]
    resistance_on <-  dF$use_pyr[tstep] | dF$use_ddt[tstep]
    
    #cat("insecticide & resistance on ",insecticide_on, resistance_on,"\n")
    

    # change population
    dF$pop[tstep+1] <- change_pop_oldcc( pop = dF$pop[tstep],
                                    rate_resistance = dF$resist_pyr[tstep],
                                    rate_growth = rate_growth,
                                    carry_cap = carry_cap,
                                    rate_insecticide_kill = rate_insecticide_kill,
                                    resistance_modifier = resistance_modifier,
                                    #initially just test whether any insecticide
                                    insecticide_on = insecticide_on,
                                    #initially just test whether pyr or ddt
                                    resistance_on = resistance_on,
                                    randomness = randomness )
    
    # change resistance
    dF$resist_pyr[tstep+1] <- change_resistance( resistance = dF$resist_pyr[tstep],
                                                  resist_incr = resist_incr,
                                                  resist_decr = resist_decr,
                                                  #initially just test whether pyr or ddt
                                                  resistance_on = resistance_on )
        
  }
  

  return(dF)
 
  
}


#' run flexible simulation of population and resistance change driven by config file
#'
#' some params driven by config file, others by function args
#'
#' @param num_tsteps number of timesteps to run simulation
#' @param pop_start start vector population
#' @param resist_freq_start effect of resistance on insecticide kill rate
#' @param rate_growth population growth rate
#' @param carry_cap carrying capacity (K) in the logistic model
#' @param rate_insecticide_kill kill rate due to insecticide
#' @param resistance_modifier modifies effect of resistance
#' @param resist_incr increase in resistance when correct insecticide present
#' @param resist_decr decrease in resistance when correct insecticide absent
#' @param l_config list of config parameters
#' @param randomness 0-1 0=none, 1=maximum
#' @param never_go_below restock at this level if pop goes below it
#' 
#' @examples
#' l_time <- run_sim_oldcc(pop_start=0.5, resist_freq_start=0.2, rate_growth=0.4, carry_cap=1, rate_insecticide_kill=0.4, resistance_modifier=1)
#' #plot default run
#' plot_sim_oldcc( run_sim_oldcc())
#' #modify params
#' plot_sim_oldcc( run_sim_oldcc( rate_insecticide_kill = 0.3, resist_incr = 0.05 ))
#' #modify config file
#' l_config <- read_config()
#' l_config2 <- config_plan(l_config, t_strt=c(1,11), t_stop=c(10,20), control_id=c('irs_pyr','irs_ddt'))
#' plot_sim_oldcc( run_sim_oldcc(l_config=l_config2, resist_incr=0.1))
#' @return list of simulation results
#' @export

run_sim_oldcc <- function(num_tsteps=20,
                    pop_start=0.5,
                    resist_freq_start=0.1,
                    rate_growth=0.2,
                    carry_cap=1,
                    rate_insecticide_kill=0.2,
                    resistance_modifier=1,
                    resist_incr = 0.2,
                    resist_decr = 0.1,
                    l_config=NULL, #list got from configuration files
                    randomness = 0,
                    never_go_below = 0.01
) 
{
  
  #read default config if none specified
  if (is.null(l_config))
    #read config files into a list, this is the old carrying capacity driven one
    l_config <- read_config(in_folder=system.file("extdata","config_oldcc_no_control", package="resistanceGame"))
  
  
  
  #initialise the list storing time data including what controls used
  l_time <- init_sim(num_tsteps=num_tsteps, l_config=l_config)
  
  l_time[[1]]$pop <- pop_start
  l_time[[1]]$resist <- resist_freq_start

  #can I allow emergence to be passed as a vector ?
  #be careful that later emergence may need to be specific to each vector
  
  #OR can I get it from l_config$places$emergence
  #l_config$places$emergence[1]
  #[1] "0.1:0.1:0.1:0.1:0.1:0.1:0.9:0.9:0.9:0.9:0.9:0.9"

  
  
  #sneaky bit of code to replicate carry_cap as many times as needed to fill all tsteps
  #this allows some flexibility in creating seasonal patterns
  if (length(carry_cap) < num_tsteps)
  {
    carry_cap <- rep_len(carry_cap, num_tsteps)
  }
  
  for( tstep in 1:(num_tsteps) )
  {
    l_time[[tstep]]$emergence <- carry_cap[tstep]
  }
  
  
  #tstep loop
  for( tstep in 1:(num_tsteps-1) )
  {
    
    #cat("t",tstep,"\n")
    
    #initially insecticide on is just if a control measure is present
    #todo later this will need to get the kill_rate from somewhere
    #or even assess whether this control measure works on this vectorl_time
    
    #insecticide_on <- l_time$use_pyr[tstep] | l_time$use_ddt[tstep] | l_time$use_ops[tstep] | l_time$use_car[tstep]
    
    #this sums all control measures
    #todo be careful with whether this should add to > 1 and what happens
    insecticide_on <- sum(l_time[[tstep]]$controls_used, na.rm=TRUE)
    
    
    #resistance_on <-  l_time$use_pyr[tstep] | l_time$use_ddt[tstep]
    
    #resistance_on is whether there is an appropriate combination
    #of resistance mechanism and control method
    #initially assume just one resistance mechanism at a time
    #it will need to test both l_time and list_config
    
    resistance_on <- is_control_incr_resist( controls_used = l_time[[tstep]]$controls_used,
                                             l_config = l_config )
    
    #cat("insecticide & resistance on ",insecticide_on, resistance_on,"\n")
    
    
    # change population
    l_time[[tstep+1]]$pop <- change_pop_oldcc( pop = l_time[[tstep]]$pop,
                                   rate_resistance = l_time[[tstep]]$resist,
                                   rate_growth = rate_growth,
                                   #carry_cap = carry_cap,
                                   carry_cap = l_time[[tstep]]$emergence,
                                   rate_insecticide_kill = rate_insecticide_kill,
                                   resistance_modifier = resistance_modifier,
                                   #initially just test whether any insecticide
                                   insecticide_on = insecticide_on,
                                   #initially just test whether pyr or ddt
                                   resistance_on = resistance_on,
                                   randomness = randomness,
                                   never_go_below = never_go_below )
    
    # change resistance
    l_time[[tstep+1]]$resist <- change_resistance( resistance = l_time[[tstep]]$resist,
                                                 resist_incr = resist_incr,
                                                 resist_decr = resist_decr,
                                                 #initially just test whether pyr or ddt
                                                 resistance_on = resistance_on )
    
  }
  
  
  return(l_time)
  
  
}

#' run flexible simulation of population and resistance change based on emergence driven by config file
#'
#' some params driven by config file, others by function args
#'
#' @param num_tsteps number of timesteps to run simulation
#' @param pop_start start vector population
#' @param resist_freq_start frequency of resistance at start, 0 to 1
#' @param resist_intensity_start intensity of resistance at start, 1 to 10
#' @param survival adult survival rate
#' @param emergence emerging adults, can be a vector can be greater than 1
#' @param rate_insecticide_kill kill rate due to insecticide
#' @param resistance_modifier modifies effect of resistance
#' @param resist_incr increase in resistance when correct insecticide present
#' @param resist_decr decrease in resistance when correct insecticide absent
#' @param l_config list of config parameters
#' @param randomness 0-1 0=none, 1=maximum
#' @param never_go_below restock at this level if pop goes below it
#' 
#' @examples
#' l_time <- run_sim(pop_start=0.5, resist_freq_start=0.2, survival=0.8, emergence=0.2, rate_insecticide_kill=0.4, resistance_modifier=1)
#' #plot default run
#' plot_sim( run_sim())
#' #modify params
#' plot_sim( run_sim( rate_insecticide_kill = 0.3, resist_incr = 0.05 ))
#' #modify config file
#' l_config <- read_config()
#' l_config2 <- config_plan(l_config, t_strt=c(1,11), t_stop=c(10,20), control_id=c('irs_pyr','irs_ddt'))
#' plot_sim( run_sim(l_config=l_config2, resist_incr=0.1))
#' @return list of simulation results
#' @export

run_sim <- function(num_tsteps=20,
                     pop_start=0.5,
                     resist_freq_start=0.1,
                     resist_intensity_start=1,
                     survival=0.7, 
                     emergence=0.3, #(equilibrium pop = emergence/(1-survival))
                     rate_insecticide_kill=0.8, #default put up from 0.2 for emerge version
                     resistance_modifier=1,
                     resist_incr = 0.2,
                     resist_decr = 0.1,
                     l_config=NULL, #list got from configuration files
                     randomness = 0,
                     never_go_below = 0.01
) 
{
  
  #read default config if none specified
  if (is.null(l_config))
    l_config <- read_config()
  
  
  #initialise the list storing time data including what controls used
  l_time <- init_sim(num_tsteps=num_tsteps, l_config=l_config)
  
  l_time[[1]]$pop <- pop_start
  l_time[[1]]$resist <- resist_freq_start
  
  #todo later put this here
  #resist_intense_start
  
  #allowing seasonal emergence to be got from config files 
  #emergence <- expand_season(season_string=l_config$places$emergence[1]) 
  #doesn't work yet ...
  #because we need to decide which entry in config file do we want if there are multiple places
  #instead can use expand_season() to set emergence (e.g. in vignette) & pass emergence to this function
  #emergence <- expand_season(season_string="6:0.1;6:0.9")
 
  
  #sneaky bit of code to replicate emergence as many times as needed to fill all tsteps
  #this allows some flexibility in creating seasonal patterns
  if (length(emergence) < num_tsteps)
  {
    emergence <- rep_len(emergence, num_tsteps)
  }
  
  for( tstep in 1:(num_tsteps) )
  {
    l_time[[tstep]]$emergence <- emergence[tstep]
  }
  
  
  #tstep loop
  for( tstep in 1:(num_tsteps-1) )
  {
    
    #cat("t",tstep,"\n")
    
    #initially insecticide on is just if a control measure is present
    #todo later this will need to get the kill_rate from somewhere
    #or even assess whether this control measure works on this vectorl_time
    
    #insecticide_on <- l_time$use_pyr[tstep] | l_time$use_ddt[tstep] | l_time$use_ops[tstep] | l_time$use_car[tstep]
    
    #this sums all control measures
    #todo be careful with whether this should add to > 1 and what happens
    insecticide_on <- sum(l_time[[tstep]]$controls_used, na.rm=TRUE)
    
    
    #resistance_on <-  l_time$use_pyr[tstep] | l_time$use_ddt[tstep]
    
    #resistance_on is whether there is an appropriate combination
    #of resistance mechanism and control method
    #initially assume just one resistance mechanism at a time
    #it will need to test both l_time and list_config
    
    resistance_on <- is_control_incr_resist( controls_used = l_time[[tstep]]$controls_used,
                                             l_config = l_config )
    
    #cat("insecticide & resistance on ",insecticide_on, resistance_on,"\n")
    
    
    # change population
    l_time[[tstep+1]]$pop <- change_pop( pop = l_time[[tstep]]$pop,
                                         rate_resistance = l_time[[tstep]]$resist,
                                         #initially have this at constant
                                         resist_intensity = resist_intensity_start,
                                         survival = survival,
                                         emergence = l_time[[tstep]]$emergence,
                                         rate_insecticide_kill = rate_insecticide_kill,
                                         resistance_modifier = resistance_modifier,
                                         #initially just test whether any insecticide
                                         insecticide_on = insecticide_on,
                                         #initially just test whether pyr or ddt
                                         resistance_on = resistance_on,
                                         randomness = randomness,
                                         never_go_below = never_go_below )
    
    # change resistance
    l_time[[tstep+1]]$resist <- change_resistance( resistance = l_time[[tstep]]$resist,
                                                   resist_incr = resist_incr,
                                                   resist_decr = resist_decr,
                                                   #initially just test whether pyr or ddt
                                                   resistance_on = resistance_on )
    
  }
  
  
  return(l_time)
  
  
}