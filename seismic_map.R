# URL de consulta a la API REST de ArcGIS de Esri Venezuela.
# Filtra y extrae en formato JSON los campos esenciales de sismicidad en tiempo real de FUNVISIS.
url <- 'https://services8.arcgis.com/F4wmVgGRtJMzSu8M/arcgis/rest/services/SISMICIDAD_TIEMPO_REAL/FeatureServer/0/query'

# Cargar librerías ----
## Función para comprobar si existen los paquetes a utilizar y cargarlos ----

install_and_load <- function(pkgs){
  missing_packages <- pkgs[!(pkgs %in% rownames(installed.packages()))]
  
  if(length(missing_packages)) {
    install.packages(missing_packages)
  }
  
  for(i in pkgs){
    library(i, character.only = T)
  }
}

## Paquetes a usar ----

paquetes <- c('jsonlite','httr2','lubridate','tidyverse','sf',
              'leaflet','leaflet.extras2','leaflegend','htmlwidgets',
              'htmltools')

## Ejecutar función ----
install_and_load(paquetes)

# Ejecutar la petición HTTP hacia la API y almacenar la respuesta del servidor ----

## Lista vacía para almacenar las estructuras de datos (dataframes) de cada página ----
todos_los_sismos <- list()

## Tamaño del lote por petición (Alineado con el límite estándar del servidor) ----
record_count <- 1000  

## Puntero inicial para la paginación (Indica cuántos registros saltarse) ----
offset <- 0

## Bandera de control para mantener activo el bucle de descarga ----
descargando <- TRUE

## Construir la petición con paginación explícita ----
while(descargando) {
  # Construir la petición con paginación explícita
  req <- request(url) |> 
    req_url_query(
      f = "json", # Formato de respuesta
      where = "1=1", # Condición booleana para traer todo
      outFields = "EPICENTRO,FECHA,HORA_HLV,ID_EVENTO,LATITUD,LONGITUD,MAGNITUD,PROFUNDIDAD,OBJECTID",
      outSR = '{"wkid":4326}', # Traer geometría WGS84
      resultRecordCount = record_count, # Límite de filas para esta iteración
      resultOffset = offset # Desplazamiento actual de la página
    )
  
  # Ejecutar la petición y procesar la respuesta
  resp <- req_perform(req)
  
  # Extraer el cuerpo de la respuesta como texto y aplanar el JSON jerárquico 
  contenido <- resp_body_string(resp) |> fromJSON(flatten = TRUE)
  
  # Extraer la matriz de características (atributos geográficos y tabulares)
  features <- contenido$features
  
  #  Control de flujo y persistencia en memoria de la página actual
  if (length(features) > 0 && nrow(features) > 0) {
    # Guardar la tanda actual
    todos_los_sismos[[length(todos_los_sismos) + 1]] <- features
    
    # Mover el puntero para la siguiente página
    offset <- offset + record_count
    message(paste("Descargados registros hasta el índice:", offset))
  } else {
    # Si ya no vienen más características, detenemos el bucle
    descargando <- FALSE
  }
}

# Unificar todas las páginas en un único dataframe
sismos_df <- do.call(rbind, todos_los_sismos)

# PROCESAMIENTO Y LIMPIEZA DE DATOS ----

## Extraer el dataframe de registros ('features') y limpiar los atributos tabulares ----
sismos_df <- sismos_df |>
  as_tibble() |>
  # Seleccionar únicamente las columnas de interés técnico
  select(
    attributes.EPICENTRO, attributes.FECHA, attributes.HORA_HLV,
    attributes.LATITUD, attributes.LONGITUD, attributes.MAGNITUD,
    attributes.PROFUNDIDAD
  )

## Renombrar las columnas de forma limpia y homogénea a minúsculas ----
names(sismos_df) <- c(
  'epicentro',
  'fecha',
  'hora',
  'latitud',
  'longitud',
  'magnitud',
  'profundidad'
)

## Mutación, formateo de fechas y corrección de anomalías espaciales ----
sismos_df <- sismos_df |>
  mutate(
    # Concatenar fecha y hora para transformarlas en formato cronológico estricto POSIXct (UTC)
    fecha = with_tz(as.POSIXct(paste(fecha, hora), format = '%d/%m/%Y %H:%M'), tzone = 'UTC'),
    
    # Control de calidad y corrección de offsets/errores tipográficos de coordenadas de la API original
    longitud = if_else(longitud == -21.42, -61.42, longitud),
    latitud = if_else(latitud == 16.65, 10.65, latitud),
    latitud = if_else(longitud == -68.81 & latitud == 6.24, 9.24, latitud),
    # Agrupar las magnitudes por grupos de escala y crear factor de magnitud
    magnitud_grupo = cut(magnitud, breaks = 1:8, right = F, labels = 1:7)
  ) |>
  select(-hora) |> # Descartar columna intermedia de hora ya unificada
  arrange(fecha) # Ordenar cronológicamente para el correcto funcionamiento del slider

## Convertir el dataframe tabular plano en un objeto geoespacial indexado ----
sismos_sf <- st_as_sf(
  sismos_df,
  coords = c('longitud','latitud'), # Mapeo de coordenadas geométricas (X, Y)
  crs = 4326 # Sistema de Referencia Geográfico Mundial Estándar WGS84
)

## Gráfico exploratorio rápido de control para evaluar magnitudes en el tiempo ----
#sismos_df |>
#  ggplot(aes(x = fecha, y = magnitud)) +
#  geom_line()

# DISEÑO DE INTERFACES DE USUARIO ----

## Cargar estructura de elementos HTML ----
source('html/estructura_html.R')

## Cargar funciones de JavaScript para el contador dinámico y el filtro de magnitud ----
source('js/funciones_js.R')

## Definir la paleta discreta basada en tonalidades de verde a rojo mapeada según la magnitud física ----
palFactor <- c('#03c700','#75b600','#a0a300','#bf8d00','#d77400','#ed5200','#ff0000')
pal <- leaflet::colorFactor(palFactor, domain = sismos_df$magnitud_grupo, reverse = F)

## Visualización en Leaflet ----
objeto_mapa <- leaflet(elementId = 'mapa-dashboard', width = '100%', height = '100%') |>
  # Mapas base intercambiables desde proveedores globales externos y asignación de los créditos de propiedad intelectual correspondientes
  addProviderTiles('CyclOSM', group = 'CyclOSM', options = providerTileOptions(attribution = '<a href=\"https://github.com/cyclosm/cyclosm-cartocss-style/releases/\">CyclOSM</a> | Datos: &copy; <a href=\"http://www.funvisis.gob.ve/\">FUNVISIS</a> via <a href=\"https://drp-venezuela-disastersesriven.hub.arcgis.com/\">Esri Venezuela DRP</a>. Visualización hecha por <a href=\"https://github.com/itsmiguelrojas/\">itsmiguelrojas</a>')) |>
  addProviderTiles('CartoDB.DarkMatter', group = 'CartoDB Dark Matter', options = providerTileOptions(attribution = '<a href=\"https://carto.com/attribution/\">CARTO</a> | Datos: &copy; <a href=\"http://www.funvisis.gob.ve/\">FUNVISIS</a> via <a href=\"https://drp-venezuela-disastersesriven.hub.arcgis.com/\">Esri Venezuela DRP</a>. Visualización hecha por <a href=\"https://github.com/itsmiguelrojas/\">itsmiguelrojas</a>')) |>
  addProviderTiles('Esri.WorldImagery', group = 'ESRI World Imagery', options = providerTileOptions(attribution = 'Tiles © Esri — Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community | Datos: &copy; <a href=\"http://www.funvisis.gob.ve/\">FUNVISIS</a> via <a href=\"https://drp-venezuela-disastersesriven.hub.arcgis.com/\">Esri Venezuela DRP</a>. Visualización hecha por <a href=\"https://github.com/itsmiguelrojas/\">itsmiguelrojas</a>')) |>
  # Incorporación y mapeo del slider de tiempo
  addTimeslider(
    data = sismos_sf,
    options = timesliderOptions(
      position = 'topright',
      timeAttribute = 'fecha',
      range = TRUE,
      alwaysShowDate = TRUE,
      showAllOnStart = TRUE
    ),
    # Configuración paramétrica visual de los marcadores circulares del sismo
    radius = ~magnitud*2,
    weight = 2,
    color = 'black',
    fillColor = ~pal(magnitud_grupo),
    fillOpacity = 0.8,
    # Construcción de la estructura e información de los Popups usando tablas HTML
    popup = ~paste(
      '<h4 style="text-align: center;"><b>Epicentro:',epicentro,
      '</b></h4>
      <hr>
      <table id="inner-box" style="border-collapse: collapse; width: 100%;">
      <tbody>
      <tr>
      <th style="border: 1px solid #000; padding: 8px; text-align: left;">Fecha y hora</th>
      <td style="border: 1px solid #000; padding: 8px;">',fecha,
      '</td></tr>
      <tr>
      <th style="border: 1px solid #000; padding: 8px; text-align: left;">Magnitud</th>
      <td style="border: 1px solid #000; padding: 8px;">',magnitud,
      '</td></tr>
      <tr>
      <th style="border: 1px solid #000; padding: 8px; text-align: left;">Profundidad</th>
      <td style="border: 1px solid #000; padding: 8px;">',profundidad,'km
      </td></tr>
      </tbody>
      </table>'
    )
  ) |>
  # Pasar el HTML dinámico con los grupos de magnitud
  addControl(
    html = panel_unificado,
    position = 'topleft'
  ) |>
  # Poner barra de escala cromática de magnitudes horizontal
  addLegendFactor(
    data = sismos_sf,
    pal = pal,
    values = ~magnitud_grupo,
    shape = 'circle',
    title = 'Magnitud',
    orientation = 'vertical',
    position = 'bottomleft'
  ) |>
  # Configurar opciones de interacción, activación e intercambio de mapas base
  addLayersControl(
    baseGroups = c('CyclOSM','CartoDB Dark Matter','ESRI World Imagery'),
    options = layersControlOptions(collapsed = FALSE),
    position = 'bottomright'
  ) |>
  # Invocar y compilar el callback de Javascript para activar la lógica del contador
  onRender(js_contador) |> 
  # Acoplar la lógica de filtrado por niveles de magnitud
  onRender(js_filtro_magnitud)

## Metadatos ----
source('html/metadatos.R')

## Estilos CSS adicionales ----
source('css/estilos_css.R')

## Ensamblar página con el resto de elementos ----
mapa_con_meta <- objeto_mapa |>
  # Adjuntar metadatos de cabecera (desde tu archivo metadatos.R)
  prependContent(metadatos) |>
  # Adjuntar CSS externo y estilos estructurales dinámicos
  prependContent(
    tags$head(
      tags$link(rel = "stylesheet", href = "css/estadisticas_estilos.css"),
      tags$style(HTML("
        body {
          display: block !important;
          margin: 0;
          padding: 0 0 0 240px !important;
          background-color: #f8f9fa !important;
          height: 100% !important;
          width: 100% !important;
          overflow: hidden !important;
        }
        /* Apuntamos directamente al ID del contenedor del mapa */
        #mapa-dashboard {
          width: calc(100vw - 240px) !important;
          height: 100vh !important;
        }
        /* Ajuste responsivo directo para el mapa en dispositivos móviles */
        @media (max-width: 768px) {
          body {
            padding: 0 !important;
            overflow-y: auto !important;
          }
        
          #mapa-dashboard {
            position: relative !important;
            width: 100vw !important;
            height: calc(100vh - 120px) !important;
          }
        }
      "))
    )
  ) |>
  # Adjuntar la estructura HTML de la barra lateral (se renderiza antes del mapa en el body)
  prependContent(html_sidebar)

## Guardar el objeto geoespacial en un archivo GeoJSON (.geojson) ----
# Comprobar primero si el archivo existe o si el número de registros es diferente en el objeto sf cargado en el entorno y en el archivo
if(!file.exists('sismos.geojson') || nrow(st_read('sismos.geojson', quiet = TRUE)) < nrow(sismos_sf)){
  message("🔄 Se detectaron sismos nuevos. Actualizando base de datos y mapa...")
  
  # 1. Guardar el objeto geoespacial actualizado
  st_write(sismos_sf, 'sismos.geojson', append = FALSE, delete_dsn = TRUE)
  
  # 2. Generar y guardar el HTML definitivo SÓLO si hay datos nuevos
  htmlwidgets::saveWidget(
    widget = mapa_con_meta,
    file = "index.html",
    selfcontained = FALSE,
    title = "Monitoreo Sísmico Venezuela - Mapa Interactivo"
  )
  
} else {
  message("✅ No hay sismos nuevos. El repositorio se mantiene sin cambios.")
}