# URL de consulta a la API REST de ArcGIS de Esri Venezuela.
# Filtra y extrae en formato JSON los campos esenciales de sismicidad en tiempo real de FUNVISIS.
url <- 'https://services8.arcgis.com/F4wmVgGRtJMzSu8M/arcgis/rest/services/SISMICIDAD_TIEMPO_REAL/FeatureServer/0/query?f=json&outFields=EPICENTRO%2CFECHA%2CHORA_HLV%2CID_EVENTO%2CLATITUD%2CLONGITUD%2CMAGNITUD%2CPROFUNDIDAD%2COBJECTID&outSR=%7B%22wkid%22%3A102100%2C%22falseM%22%3A-100000%2C%22falseX%22%3A-20037700%2C%22falseY%22%3A-30241100%2C%22falseZ%22%3A-100000%2C%22mTolerance%22%3A0.001%2C%22mUnits%22%3A10000%2C%22xyTolerance%22%3A0.001%2C%22xyUnits%22%3A10000%2C%22zTolerance%22%3A0.001%2C%22zUnits%22%3A10000%7D&returnM=true&returnZ=true&spatialRel=esriSpatialRelIntersects&where=1%3D1'

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
req <- request(url) |>
  req_perform()

# PROCESAMIENTO Y LIMPIEZA DE DATOS ----

## Convertir la respuesta binaria de la API en una cadena de texto plana ----
datos_texto <- resp_body_string(req)

## Deserializar el texto JSON plano en una estructura de listas anidadas de R ----
puntos <- jsonlite::fromJSON(datos_texto, flatten = TRUE)

## Extraer el dataframe de registros ('features') y limpiar los atributos tabulares ----
sismos_df <- puntos[['features']] |>
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

## Inyectar estilos CSS específicos para posicionar y flotar el título del mapa de manera fija ----
map_title <- tags$style(HTML('
  .leaflet-control.map-title { 
    position: fixed !important; 
    left: 50%; 
    transform: translateX(-50%);
    text-align: center; 
    padding-left: 10px; 
    padding-right: 10px; 
    background: rgba(255,255,255,0.75); 
    font-weight: bold; 
    font-size: 24px;
    border-radius: 4px;
  }
'))

## Crear el contenedor div físico que encapsula el título del mapa ----
title_div <- tags$div(
  map_title,
  HTML('Monitoreo Sísmico Venezuela')
)

## Script de JavaScript para controlador y contador dinámico ----
js_contador <- "
function(el, x) {
      var map = this;
      
      // 1. Crear y definir el contenedor personalizado en el mapa
      var counterControl = L.control({position: 'bottomright'});
      
      counterControl.onAdd = function (map) {
        this._div = L.DomUtil.create('div', 'dynamic-counter-box'); 
        
        // Estilos CSS directos para dar apariencia de widget o caja de visualización
        this._div.style.backgroundColor = 'rgba(255, 255, 255, 0.95)';
        this._div.style.padding = '12px 16px';
        this._div.style.borderRadius = '8px';
        this._div.style.boxShadow = '0 3px 8px rgba(0,0,0,0.25)';
        this._div.style.fontSize = '13px';
        this._div.style.fontFamily = 'Helvetica, Arial, sans-serif';
        this._div.style.color = '#2c3e50';
        this._div.style.border = '1px solid #bdc3c7';
        this._div.style.lineHeight = '1.6';
        
        this.update(0, 'N/A', 'N/A');
        return this._div;
      };
      
      // Función interna para actualizar el código HTML según los datos calculados
      counterControl.update = function (count, start, finish) {
        this._div.innerHTML = 
          '<div style=\"font-weight: bold; font-size: 14px; margin-bottom: 6px; border-bottom: 2px solid #ecf0f1; padding-bottom: 4px;\">📊 Ventana sísmica</div>' +
          '🔢 <b>Eventos registrados:</b> ' + count + '<br>' +
          '⏱️ <b>Desde:</b> <span style=\"color: #2980b9; font-weight: bold;\">' + start + '</span><br>' +
          '🏁 <b>Hasta:</b> <span style=\"color: #c0392b; font-weight: bold;\">' + finish + '</span>';
      };
      
      counterControl.addTo(map);
      
      // 2. Lógica para rastrear, extraer y ordenar marcas temporales del mapa en vivo
      var countTimeout;
      function recalculateRecords() {
        clearTimeout(countTimeout);
        
        // Retrasar el cálculo 40ms para asegurar fluidez de fotogramas al arrastrar el slider
        countTimeout = setTimeout(function() {
          var count = 0;
          var activeTimes = []; // Matriz contenedora de marcas de tiempo visibles
          
          map.eachLayer(function (layer) {
            // Verificar estrictamente que la capa corresponda a un marcador sísmico con propiedad 'fecha'
            if (layer.feature && layer.feature.properties && layer.feature.properties.fecha) {
              count++;
              activeTimes.push(layer.feature.properties.fecha);
            }
          });
          
          var startTime = 'N/A';
          var finishTime = 'N/A';
          
          // Si hay capas visibles en pantalla, ordenar alfabéticamente para hallar los límites temporales
          if (activeTimes.length > 0) {
            activeTimes.sort(); // Alphabetic sort works perfectly for YYYY-MM-DD HH:MM:SS structures
            startTime = activeTimes[0];
            finishTime = activeTimes[activeTimes.length - 1];
          }
          
          // Enviar los resultados finales a la interfaz gráfica de la caja
          counterControl.update(count, startTime, finishTime);
        }, 40); // 40ms debounce to optimize render scrolling frame rates
      }
      
      // 3. Capturar eventos de adición/remoción de capas generados por el Timeslider
      map.on('layeradd layerremove', function(e) {
        if (e.layer && e.layer.feature) {
          recalculateRecords();
        }
      });
      // Ejecutar inicialización única al cargar por primera vez el mapa
      recalculateRecords();
    }
"

## Definir la paleta discreta basada en tonalidades de verde a rojo mapeada según la magnitud física ----
palFactor <- c('#03c700','#75b600','#a0a300','#bf8d00','#d77400','#ed5200','#ff0000')
pal <- leaflet::colorFactor(palFactor, domain = sismos_df$magnitud_grupo, reverse = F)

## Visualización en Leaflet ----
objeto_mapa <- leaflet() |>
  # Mapas base intercambiables desde proveedores globales externos
  addProviderTiles('CyclOSM', group = 'CyclOSM') |>
  addProviderTiles('CartoDB.DarkMatter', group = 'CartoDB Dark Matter') |>
  addProviderTiles('Esri.WorldImagery', group = 'ESRI World Imagery') |>
  # Agregar capa estándar asignando los créditos de propiedad intelectual correspondientes
  addTiles(
    attribution = 'Datos: &copy; <a href=\"http://www.funvisis.gob.ve/\">FUNVISIS</a> via <a href=\"https://drp-venezuela-disastersesriven.hub.arcgis.com/\">Esri Venezuela DRP</a>'
  ) |>
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
  # Agregar el widget flotante del título del mapa
  addControl(
    html = title_div, 
    position = 'topleft',
    className = 'map-title'
  ) |>
  # Poner barra de escala cromática de magnitudes horizontal
  addLegendFactor(
    data = sismos_sf,
    pal = pal,
    values = ~magnitud_grupo,
    shape = 'circle',
    title = 'Magnitud',
    orientation = 'horizontal',
    position = 'bottomleft'
    #width = 150,
    #height = 15
  ) |>
  # Configurar opciones de interacción, activación e intercambio de mapas base
  addLayersControl(
    baseGroups = c('CyclOSM','CartoDB Dark Matter','ESRI World Imagery'),
    options = layersControlOptions(collapsed = FALSE),
    position = 'bottomleft'
  ) |>
  # Invocar y compilar el callback de Javascript para activar la lógica del contador
  onRender(js_contador)

## Definir las etiquetas meta que irán dentro del <head> del HTML final ----
metadatos <- tags$head(
  # Metadatos Estándar
  tags$meta(name = 'viewport', content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, interactive-widget=resizes-content'),
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

## Poner los metadatos en la cabecera del widget de Leaflet ----
mapa_con_meta <- htmlwidgets::prependContent(objeto_mapa, metadatos)

## Guardar el objeto geoespacial en un archivo GeoPackage (.gpkg) ----
# Comprobar primero si el archivo existe o si el número de registros es diferente en el objeto sf cargado en el entorno y en el archivo
if(!file.exists('sismos.gpkg') || nrow(st_read('sismos.gpkg', quiet = TRUE)) < nrow(sismos_sf)){
  message("🔄 Se detectaron sismos nuevos. Actualizando base de datos y mapa...")
  
  # 1. Guardar el objeto geoespacial actualizado
  st_write(sismos_sf, 'sismos.gpkg', append = FALSE)
  
  # 2. Generar y guardar el HTML definitivo SÓLO si hay datos nuevos
  htmlwidgets::saveWidget(
    widget = mapa_con_meta,
    file = "index.html",
    selfcontained = TRUE,
    title = "Monitoreo Sísmico Venezuela - Mapa Interactivo"
  )
  
} else {
  message("✅ No hay sismos nuevos. El repositorio se mantiene sin cambios.")
}