library(sf)
library(tidyverse)
library(plotly)

sismos <- st_read('sismos.geojson') |> st_drop_geometry()

sismos <- sismos |>
  as_tibble() |>
  mutate(fecha = as.Date(fecha))

mw_diario <- function(data, col_mag = 'mag'){
  M0 <- 10^(1.5*data[,col_mag]+9.09) |> # Conversión a momento sísmico
    pull()
  
  sigma_M0 <- M0*(1.5*log(10))*0.1 # Incertidumbre de cada momento sísmico
  
  data_new <- cbind(data, M0, sigma_M0) |> as_tibble()
  
  data_new_summary <- data_new |>
    filter(!is.na(fecha)) |>
    group_by(fecha) |>
    summarise(
      mag = col_mag,
      sum_M0 = sum(M0), # Suma total del momento sísmico diario
      sigma_sum_M0 = sqrt(sum(sigma_M0^2)), # Incertidumbre del momento sísmico diario
      Mw_tot = (2/3)*log10(sum_M0)-6.06, # Magnitud momento equivalente del total
      sigma_Mw_tot = (2/(3*log(10)))*(sigma_sum_M0/sum_M0) # Incertidumbre de la magnitud momento
    )
  
  return(data_new_summary)
}

momento_equiv <- mw_diario(sismos, 'magnitud')

momento_plot <- momento_equiv |>
  ggplot(aes(x = fecha, y = Mw_tot)) +
  geom_line(color = 'red') +
  geom_errorbar(aes(ymin = Mw_tot - sigma_Mw_tot, ymax = Mw_tot + sigma_Mw_tot), width = 0.8, color = 'black') +
  geom_point(color = 'red')

ggplotly(momento_plot)