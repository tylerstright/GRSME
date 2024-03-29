#' @title sumGRSMEdisp
#'
#' @description takes prepared FINS Data and generates dispostion summaries for weir report with recaps
#' both included and excluded.
#'
#' @param data FINS data filtered for year, trap, and species of interest
#' @author Tyler Stright
#'
#' @examples 
#'
#' @import tidyverse, lubridate
#' @export
#' @return NULL


sumSTHdisp <- function(data, origin_, trap.year) {
  
  recaps_yn <- c('Include Recaps', 'Exclude Recaps')
  
  for(j in 1:length(recaps_yn)) {
    # Assign Dispositions based on moved_to
    disp_summary <- data %>%
      filter(trap_year == trap.year,  
             species == "Steelhead",
             if(recaps_yn[j]=='Include Recaps') {recap==recap} else {recap == FALSE}
      ) %>%  
      mutate(Class = case_when(
        sex == 'Male' ~ 'M',
        sex == 'Female' ~ 'F'),
        Disposition = case_when(
          living_status %in% c('DOA', 'TrapMort') ~ 'Mortality', 
          disposition == 'Released' & str_detect(moved_to, 'Wallowa River') & purpose == 'Recycled' ~ 'Recycled to Fishery',
          disposition == 'Released' & str_detect(moved_to, 'Wallowa River') & purpose == 'Outplant' ~ 'Wallowa River Outplant',
          disposition == 'Released' & moved_to %in% c('Lostine River: Above Weir', 'Lostine River: Acclimation Facility') ~ 'Upstream Release',
          disposition %in% c('Ponded', 'Transferred') ~ 'Brood Collection',
          disposition == 'Disposed' ~ 'Food Distribution'
        )) %>%
      group_by(Disposition, Class, origin) %>%
      summarize(Count = sum(count)) 
    
    disposition_list <- c('Upstream Release', 'Brood Collection', 'Food Distribution', 'Wallowa River Outplant', 'Recycled to Fishery', 'Mortality')
    
    # Dispositions Summary 
    disp_df <- disp_summary %>%
      filter(origin == origin_) %>%
      spread(key= Class, value = Count, fill = 0) 
    
    if(!"F" %in% colnames(disp_df)) {   # Add Females if not present
      disp_df$`F` <- 0
    }
    if(!"M" %in% colnames(disp_df)) {   # Add Males if not present
      disp_df$M <- 0
    }
    
    disp_df <- disp_df %>%
      mutate(`Total [all]` = +`F`+`M`) %>%
      select(`Disposition`, `F`, `M`, `Total [all]`, `origin`) %>%
      ungroup() %>%
      select(-origin)
    
    disp_tot <- apply(disp_df[,c(2:4)], 2, sum) 
    
    disp_df <- disp_df %>%
      add_row(Disposition = 'Total', `F`= disp_tot[1], `M`= disp_tot[2], `Total [all]`= disp_tot[3])
    
    # If there is no data for a disposition, add a row showing zeros.
    for (i in 1:length(disposition_list)) {
      if(!disposition_list[i] %in% unique(disp_df$Disposition)) {
        disp_df <- disp_df %>%
          add_row(Disposition = disposition_list[i], `F`= 0, `M`= 0, `Total [all]`= 0)
      } else {
        next
      }
    }
    
    # order dispositions as desired
    disp_df <- disp_df[order(match(disp_df$Disposition, c('Upstream Release', 'Brood Collection', 'Food Distribution', 
                                                          'Wallowa River Outplant', 'Recycled to Fishery', 'Mortality', 'Total'))),]
    # rename dataframes based on recaps_yn
    if(recaps_yn[j] == 'Include Recaps') {
      assign(paste0('recaps_df'), disp_df)
    }
    if(recaps_yn[j] == 'Exclude Recaps') {
      assign(paste0('exclude_recaps_df'), disp_df)
    }
    
    # keep data, recaps_yn, & origin_
    rm(disp_df, disp_summary, disp_tot, disposition_list, i)
  }
  
  # combine into final df
  join_df <- left_join(recaps_df, exclude_recaps_df, by = 'Disposition') %>%
    mutate(`F` = paste(`F.x`, ' (', `F.y`, ')', sep=''),
           `M` = paste(`M.x`, ' (', `M.y`, ')', sep=''),
           `Total [all]` = paste(`Total [all].x`, ' (', `Total [all].y`, ')', sep='')) %>%
    select(Disposition, `F`, M, `Total [all]`)
  
  return(join_df)
}
