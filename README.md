# Mapa sísmico interactivo con deslizador temporal y contador dinámico

## ⚠️ Advertencia

> **Información importante:** Mi ámbito de estudio corresponde a la **biología** y no a las áreas de geología, geografía, sismología o similares. 
> 
> Este proyecto ha sido desarrollado con un enfoque estrictamente técnico en ciencia de datos, automatización y sistemas de información geográfica (SIG), con el único propósito de contribuir a la visualización accesible de la información tras los eventos sísmicos del 24 de junio de 2026 en Venezuela. 
> 
> Los datos cartográficos y de registro se extraen de fuentes oficiales. Esta plataforma es una herramienta de visualización complementaria y de código abierto la cual no debe ser utilizada como sustituto de los canales oficiales de gestión de riesgos ni para análisis geofísicos formales.

Este repositorio contiene una visualización en mapa interactiva e independiente para el seguimiento de los eventos sísmicos registrados en Venezuela tras el doble terremoto del 24 de junio de 2026. Está construido en R utilizando los paquetes `leaflet` y `leaflet.extras2`, e incluye una capa personalizada en JavaScript que cuenta dinámicamente los registros activos y recalcula las ventanas de tiempo sobre la marcha, **sin necesidad de un servidor o backend en Shiny.**

## Estructura del repositorio

* **`seismic_map.R`**: El script principal en R que gestiona la transformación de datos mediante `sf`, la configuración de Leaflet y el bloque de código de JavaScript nativo (`htmlwidgets::onRender`).
* **`index.html`**: El mapa interactivo final compilado.

---

## Características

* **Filtrado temporal**: Deslizador interactivo de doble control (rango) para restringir visualmente los sismos mostrados según intervalos de inicio y fin.
* **Ventana de contador dinámico**: Una caja de control de tipo `<div>` con estilos personalizados que se actualiza instantáneamente al arrastrar el deslizador, mostrando:
  * El número total de eventos registrados visibles en ese instante.
  * La fecha y hora del sismo más antiguo en el rango seleccionado.
  * La fecha y hora del sismo más reciente en el rango seleccionado.

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

### Ejecución del proyecto

1. Abre el archivo `seismic_map.R` en tu entorno de R.
2. Ejecuta el código para procesar los datos de la API y renderizar el mapa interactivo.
3. Para exportar y guardar el mapa como el archivo HTML independiente incluido en este repositorio, añade la siguiente línea al final del flujo de código:
```R
htmlwidgets::saveWidget(mapa_con_meta, "index.html", selfcontained = TRUE)

```



---

## Atribución y fuente de los datos

Los datos que alimentan esta visualización provienen de [Terremoto Venezuela](https://drp-venezuela-disastersesriven.hub.arcgis.com/).

* **Proveedor principal de datos**: [FUNVISIS](http://www.funvisis.gob.ve/) (Fundación Venezolana de Investigaciones Sismológicas).
* **Plataforma del dashboard**: Alojado por Esri Venezuela a través de su **Programa de Respuesta a Desastres (DRP)**.
* **Enlace al dashboard original**: [Monitoreo Sísmico Venezuela](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47).

### Referencias

> Fundación Venezolana de Investigaciones Sismológicas (FUNVISIS). (2026). *Monitoreo Sísmico Venezuela* [ArcGIS Dashboard]. Distribuido por Esri Venezuela Programa de Respuesta a Desastres (DRP). Obtenido de [https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47)