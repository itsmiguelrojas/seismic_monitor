## Definir las etiquetas meta que irán dentro del <head> del HTML final ----
metadatos <- tags$head(
  # Metadatos Estándar
  tags$meta(name = 'viewport', content = 'width=device-width, initial-scale=0.9, maximum-scale=0.9, user-scalable=no, interactive-widget=resizes-content'),
  tags$meta(name = 'keywords', content = 'sismos, venezuela, funvisis, leaflet, rstats, mapa interactivo, sismicidad'),
  tags$meta(name = 'author', content = 'itsmiguelrojas'),
  
  # Protocolo Open Graph (OG)
  tags$meta(property = 'og:type', content = 'website'),
  tags$meta(property = 'og:title', content = 'Monitoreo Sísmico Venezuela - Mapa Interactivo'),
  tags$meta(property = 'og:description', content = 'Visualización interactiva y filtrado temporal de eventos sísmicos.'),
  tags$meta(property = 'og:url', content = 'https://itsmiguelrojas.github.io/seismic_monitor/'),
  tags$meta(property = 'og:image', content = 'https://raw.githubusercontent.com/itsmiguelrojas/seismic_monitor/main/main.png'),
  tags$meta(property = 'og:image:alt', content = "Vista previa del mapa de monitoreo sísmico con controles y marcas circulares"),
  
  # Tarjetas de Twitter / X
  tags$meta(name = 'twitter:card', content = 'summary_large_image'),
  tags$meta(name = 'twitter:title', content = 'Monitoreo Sísmico Venezuela - Mapa Interactivo'),
  tags$meta(name = 'twitter:description', content = 'Visualización interactiva y filtrado temporal de eventos sísmicos.'),
  tags$meta(name = 'twitter:image', content = 'https://raw.githubusercontent.com/itsmiguelrojas/seismic_monitor/main/main.png')
)