# 📡 Sismos VE - Monitoreo Sísmico Venezuela

## ⚠️ Advertencia
> Mi ámbito de estudio corresponde a la **biología** y no a las áreas de geología, geografía, sismología o similares.
>
> Este proyecto ha sido desarrollado con un enfoque estrictamente técnico en ciencia de datos, automatización y sistemas de información geográfica (SIG), con el único propósito de contribuir a la visualización accesible de la información tras los eventos sísmicos del 24 de junio de 2026 en Venezuela.
>
> Los datos cartográficos y de registro se extraen de fuentes oficiales. Esta plataforma es una herramienta de visualización complementaria y de código abierto la cual no debe ser utilizada como sustituto de los canales oficiales de gestión de riesgos ni para análisis geofísicos formales.

Este repositorio contiene una plataforma interactiva e independiente de visualización y análisis estadístico para el seguimiento de los eventos sísmicos en Venezuela. El ecosistema está diseñado bajo una arquitectura híbrida: procesa y compila datos a través de R (`leaflet` y `leaflet.extras2`), inyectando interactividad fluida con **JavaScript puro** (y con ayuda de librerías como [Chart.js](https://www.chartjs.org/) y [Chart.js Box and Violin Plot](https://github.com/sgratzl/chartjs-chart-boxplot)) y **CSS3**, lo que elimina por completo la necesidad de un servidor o backend activo en Shiny.

---

## Demostración en vivo

El sistema se encuentra desplegado de manera estática y pública en dos secciones interconectadas por un menú de navegación unificado:

* **[📡 Monitoreo Principal (mapa interactivo)](https://itsmiguelrojas.github.io/seismic_monitor/)**
* **[📊 Estadística Descriptiva (panel de análisis)](https://itsmiguelrojas.github.io/seismic_monitor/estadisticas/)**

---

## Características principales

### 1. Monitor Principal (visualización cartográfica)
* **Contador dinámico de sismos:** Un widget flotante que calcula y muestra en tiempo real la cantidad de eventos activos en pantalla, adaptando además la ventana temporal visible en el deslizador.
* **Control temporal de rango:** Deslizador interactivo de doble control (dual-slider) para restringir dinámicamente los sismos mostrados según intervalos específicos de inicio y fin.
* **Control de capas y leyendas:** Configuración detallada sobre la tesela base de `CyclOSM` y leyendas dinámicas posicionadas estratégicamente para mejorar la UX.
* **Información sobre sismos y fallas**: Al hacer clic sobre un sismo registrado (punto) o sobre una falla (línea), se muestra una ventana emergente (popup) con información sobre la misma.

### 2. Panel de Estadística Descriptiva (`/estadisticas/`)
* **Filtrado cruzado:** Integración de selectores múltiples (checkboxes) por grupos de magnitud combinados con el filtrado por rangos de fecha.
* **Gráficos estadísticos dinámicos:** Gráficos optimizados y responsivos que coexisten verticalmente sin comprometer el rendimiento de la pestaña.

### 3. Arquitectura de diseño y UI/UX global
* **Menú lateral unificado (`sidebar`):** Un componente fijo (`<aside>`) presente en ambas páginas para un intercambio inmediato de vistas, con clases activas diferenciadas visualmente.
* **Cálculo dinámico de pantalla (Calculated CSS):** Para evitar que el mapa de Leaflet se corte por el ancho de la barra lateral, se implementó posicionamiento absoluto y restas dinámicas basadas en Viewport Units (`width: calc(100vw - 240px)`) para garantizar la accesibilidad completa a la leyenda, los deslizadores y el control de capas.

---

## Sugerencias

La evolución técnica de esta visualización se ha beneficiado del intercambio de ideas y el control de calidad por parte de pares académicos, y está bajo constante desarrollo. A continuación, se presenta una lista de sugerencias:

|Sugerido por|Sugerencia|Características|
|:---|:---|:---|
|[Mariangel Milano](https://linkedin.com/in/mariangel-milano-espinoza-a47419188)|Filtro desplegable por grupos de magnitud|<ul><li>Contenedor flotante nativo basado en etiquetas HTML5 `<details>` y `<summary>` para un despliegue ligero en dispositivos móviles, acompañado de casillas de verificación dinámicas.</li><li>Para resolver las limitaciones de Leaflet sobre elementos ocultos (<code>opacity: 0</code>), se inyectó una propiedad en el árbol DOM (<code>pointer-events: none/auto</code>) que previene la activación accidental de popups "fantasma" de sismos que han sido desactivados visualmente en el panel.</li></ul>|
---

## Configuración e instalación

Para ejecutar este script localmente, asegúrate de tener instalado R o RStudio junto con las siguientes dependencias:

```R
install.packages(c("jsonlite", "httr2", "lubridate", "tidyverse", "sf", "leaflet", "leaflet.extras2", "leaflegend", "htmlwidgets", "htmltools"))

```

### Ejecución y compilación del proyecto

El ensamblaje del mapa interactivo se ha rediseñado para conservar intacta la clase `htmlwidget` del mapa. Esto evita degradar el objeto a un tipo genérico `shiny.tag` y permite usar de forma nativa la función `prependContent()` de `htmlwidgets` para inyectar cabeceras, CSS y estructuras HTML antes de renderizar:

```r
## Visualización en Leaflet ----
objeto_mapa <- leaflet(elementId = 'mapa-dashboard', width = '100%', height = '100%') |>
  addProviderTiles('CyclOSM')) |>
  # ... [Configuración de sismos, filtros y popups] ...
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
```

---

## Atribución y fuente de los datos

Los datos que alimentan esta visualización provienen de [Terremoto Venezuela](https://drp-venezuela-disastersesriven.hub.arcgis.com/).

* **Proveedor principal de datos**: [FUNVISIS](http://www.funvisis.gob.ve/) (Fundación Venezolana de Investigaciones Sismológicas).
* **Plataforma del dashboard**: Alojado por Esri Venezuela a través de su **Programa de Respuesta a Desastres (DRP)**.
* **Enlace al dashboard original**: [Monitoreo Sísmico Venezuela](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47).

### Referencias

> Fundación Venezolana de Investigaciones Sismológicas (FUNVISIS). (2026). *Monitoreo Sísmico Venezuela* [ArcGIS Dashboard]. Distribuido por Esri Venezuela Programa de Respuesta a Desastres (DRP). Obtenido de [https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47)