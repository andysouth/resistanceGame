#' create an example lookup table that could be used by a game to direct it's behaviour
#'
#' this is a prototype to explore what a lookup table might look like
#'
#' @param input_values
#' @param write_csv a filename or NULL for no csv output
#' @param carryCap carrying capacity (K) in the logistic model
#' @param rateInsecticideKill kill rate due to insecticide
#' @param rateResistance effect on resistance on insecticide kill rate
#' @param resistanceModifier modifies effect of resistance
#' @examples
#' create_lookup(write_csv=NULL)
#' @return float population in next timestep
#' @export


create_lookup <- function(   inputValues = list( use_pyr=c(0,1), 
                                                 use_ddt=c(0,1),
                                                 use_ops=c(0,1),
                                                 use_car=c(0,1),
                                                 pop_vector=seq(0,1,0.1),
                                                 resist_pyr=seq(0,1,0.1) ),
                             write_csv = 'demoLookupTable.csv'
                          ){
 
  
 

  inputs <- expand.grid(inputValues)

  #adding on outputs columns
  #columnsOutput <- c('change_pop_vector','change_resist_pyr')
  
  #todo: get this to fill the output columns based on the logistic equations
  #maybe put the logistic equations from shinyGame1.r into package functions
  #but only bother doing that if we are going to do much more with this
  #remember that this is not the objective
  #inputs$change_pop_vector <- 0
  inputs$change_pop_vector <- change_pop( pop = inputs$pop_vector,
                                          rate_growth = 0.4,
                                          carry_cap = 1,
                                          rate_insecticide_kill = 0.4,
                                          rate_resistance = inputs$resist_pyr,
                                          resistance_modifier = 1,
                                          #initially just test whether any insecticide
                                          insecticide_on = inputs$use_pyr || inputs$use_ddt || inputs$use_ops || inputs$use_car,
                                          #initially just test whether pyr or ddt
                                          resistance_on = inputs$use_pyr || inputs$use_ddt )
  
  
  inputs$change_resist_pyr <- 0
  
  if ( !is.null(write_csv) )
    write.csv(inputs, file=write_csv)
  
  return(inputs)
   
}