library(dplyr)
library(stringr)
library(tibble)

fallas2 <- fallas |>
  mutate(
    slip_group = case_when(
      is.na(slip_type) ~ "Sin etiqueta",
      
      # Convergentes (Reverse/Subduction)
      str_detect(slip_type, "Reverse|Subduction_Thrust") ~ "Convergente",
      
      # Extensivas (Normal)
      str_detect(slip_type, "Normal") ~ "Extensiva",
      
      # Cizalla lateral “pura” / transform dextral
      slip_type %in% c("Dextral", "Sinistral", "Dextral_Transform") ~ "Cizalla lateral",
      
      str_detect(slip_type, " ") ~ "Sin etiqueta",
      
      # Si cae algo raro no capturado (p. ej. combinaciones no contempladas)
      TRUE ~ "Mixta/Oblicua"
    )
  ) |>
  relocate(slip_group, .before = geometry)