# Mapa sísmico interactivo con Deslizador Temporal y Contador Dinámico

Este repositorio contiene una visualización en mapa interactiva e independiente para el seguimiento de los eventos sísmicos registrados en Venezuela tras el doble terremoto del 24 de junio de 2026. Está construido en R utilizando los paquetes `leaflet` y `leaflet.extras2`, e incluye una capa personalizada en JavaScript que cuenta dinámicamente los registros activos y recalcula las ventanas de tiempo sobre la marcha, **sin necesidad de un servidor o backend en Shiny.**

## Estructura del Repositorio

* **`seismic_map.R`**: El script principal en R que gestiona la transformación de datos mediante `sf`, la configuración de Leaflet y el bloque de código de JavaScript nativo (`htmlwidgets::onRender`).
* **`index.html`**: El mapa interactivo final compilado.

---

## Características

* **Filtrado temporal**: Deslizador interactivo de doble control (rango) para restringir visualmente los sismos mostrados según intervalos de inicio y fin.
* **Ventana de contador dinámico**: Una caja de control de tipo `<div>` con estilos personalizados que se actualiza instantáneamente al arrastrar el deslizador, mostrando:
* El número total de **Eventos registrados** visibles en ese instante.
* La fecha y hora del sismo más antiguo en el rango seleccionado.
* La fecha y hora del sismo más reciente en el rango seleccionado.

---

## Configuración e instalación

Para ejecutar este script localmente, asegúrate de tener instalado R o RStudio junto con las siguientes dependencias:

```R
install.packages(c("jsonlite", "httr2", "lubridate", "tidyverse", "sf", "leaflet", "leaflet.extras2", "leaflegend", "htmlwidgets", "htmltools"))

```

### Ejecución del Proyecto

1. Abre el archivo `seismic_map.R` en tu entorno de R.
2. Ejecuta el código para procesar los datos de la API y renderizar el mapa interactivo.
3. Para exportar y guardar el mapa como el archivo HTML independiente incluido en este repositorio, añade la siguiente línea al final del flujo de código:
```R
htmlwidgets::saveWidget(objeto_mapa, "index.html", selfcontained = TRUE)

```



---

## Atribución y fuente de los datos

Los datos que alimentan esta visualización provienen de [Monitoreo Sísmico Venezuela](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47#).

* **Proveedor Principal de Datos**: [FUNVISIS](http://www.funvisis.gob.ve/) (Fundación Venezolana de Investigaciones Sismológicas).
* **Plataforma del dashboard**: Alojado por Esri Venezuela a través de su *Programa de Respuesta a Desastres*.
* **Enlace al dashboard original**: [Monitoreo Sísmico Venezuela Dashboard](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47)

### Referencias

> Fundación Venezolana de Investigaciones Sismológicas (FUNVISIS). (2026). *Monitoreo Sísmico Venezuela* [ArcGIS Dashboard]. Distribuido por Esri Venezuela Programa de Respuesta a Desastres. Obtenido de [https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47](https://disastersesriven.maps.arcgis.com/apps/dashboards/8457c6fde45c4b9e921aff896474bc47)